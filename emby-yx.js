const CONFIG = {
  UPSTREAM_URL: 'https://www.baidu.com',
  STATIC_REGEX: /(\.(jpg|jpeg|png|gif|css|js|ico|svg|webp|woff|woff2)|(\/Images\/(Primary|Backdrop|Logo|Thumb|Banner|Art)))/i,
  VIDEO_REGEX: /(\/Videos\/|\/Items\/.*\/Download|\/Items\/.*\/Stream)/i,
  API_CACHE_REGEX: /(\/Items\/Resume|\/Users\/.*\/Items\/)/i,
  API_TIMEOUT: 2500
};

async function fetchWithTimeout(url, options, timeout) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeout);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    clearTimeout(id);
    return response;
  } catch (error) {
    clearTimeout(id);
    throw error;
  }
}

async function handleRequest(request) {
  const req = request;
  const url = new URL(req.url);
  const targetUrl = new URL(url.pathname + url.search, CONFIG.UPSTREAM_URL);
  
  const proxyHeaders = new Headers(req.headers);
  proxyHeaders.set('Host', targetUrl.hostname);
  proxyHeaders.set('Referer', targetUrl.origin);
  proxyHeaders.set('Origin', targetUrl.origin);
  
  proxyHeaders.delete('cf-connecting-ip');
  proxyHeaders.delete('x-forwarded-for');
  proxyHeaders.delete('cf-ray');
  proxyHeaders.delete('cf-visitor');

  let reqBody = req.body;
  if (!['GET', 'HEAD'].includes(req.method) && !url.pathname.includes('/Upload')) {
    reqBody = await req.arrayBuffer();
    proxyHeaders.delete('content-length');
  }

  const isStatic = CONFIG.STATIC_REGEX.test(url.pathname);
  const isVideo = CONFIG.VIDEO_REGEX.test(url.pathname);
  const isApiCacheable = CONFIG.API_CACHE_REGEX.test(url.pathname);
  const isWebSocket = req.headers.get('Upgrade') === 'websocket';

  const cfConfig = {
    cacheEverything: isStatic,
    cacheTtl: isStatic ? 31536000 : 0,
    cacheTtlByStatus: isApiCacheable ? { "200-299": 10 } : null,
    polish: isStatic ? 'lossy' : 'off',
    minify: { javascript: isStatic, css: isStatic, html: isStatic },
    mirage: false,
    scrapeShield: false,
    apps: false,
  };

  if (isApiCacheable) {
    cfConfig.cacheEverything = true;
  }

  const fetchOptions = {
    method: req.method,
    headers: proxyHeaders,
    body: reqBody,
    redirect: 'manual',
    cf: cfConfig
  };

  try {
    let response;
    if (isVideo || isWebSocket || req.method === 'POST') {
      response = await fetch(targetUrl.toString(), fetchOptions);
    } else {
      try {
        response = await fetchWithTimeout(targetUrl.toString(), fetchOptions, CONFIG.API_TIMEOUT);
      } catch (err) {
        response = await fetch(targetUrl.toString(), fetchOptions);
      }
    }

    const resHeaders = new Headers(response.headers);
    resHeaders.delete('content-security-policy');
    resHeaders.delete('clear-site-data');
    resHeaders.set('access-control-allow-origin', '*');

    if (isVideo) {
      resHeaders.set('Connection', 'close');
    }
    
    if (isStatic && response.status === 200) {
      resHeaders.set('Cache-Control', 'public, max-age=31536000, immutable');
      resHeaders.delete('Pragma');
      resHeaders.delete('Expires');
    }

    if (response.status === 101) {
      return new Response(null, { status: 101, webSocket: response.webSocket, headers: resHeaders });
    }

    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = resHeaders.get('location');
      if (location) {
        const locUrl = new URL(location, targetUrl.href);
        if (locUrl.hostname === targetUrl.hostname) {
          resHeaders.set('Location', locUrl.pathname + locUrl.search);
        }
      }
      return new Response(null, { status: response.status, headers: resHeaders });
    }

    return new Response(response.body, {
      status: response.status,
      headers: resHeaders
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: `Proxy Error: ${error.message}` }), { status: 502 });
  }
}

export default {
  async fetch(request, env, ctx) {
    return handleRequest(request);
  }
};
