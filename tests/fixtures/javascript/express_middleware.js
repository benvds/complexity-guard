// Fixture: Express-style middleware
// Purpose: Test real-world patterns from Node.js/Express codebases
// Expected complexity: errorHandler ~6, rateLimiter ~3, inner middleware ~4

function errorHandler(err, req, res, next) {
  if (err.type === 'validation') {
    res.status(400).json({ error: err.message, fields: err.fields });
  } else if (err.type === 'auth') {
    if (err.code === 'TOKEN_EXPIRED') {
      res.status(401).json({ error: 'Token expired', action: 'refresh' });
    } else if (err.code === 'FORBIDDEN') {
      res.status(403).json({ error: 'Access denied' });
    } else {
      res.status(401).json({ error: 'Authentication required' });
    }
  } else {
    console.error('Unhandled error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
}

function rateLimiter(options) {
  const store = new Map();
  return function(req, res, next) {
    const key = req.ip || req.connection.remoteAddress;
    const now = Date.now();
    const record = store.get(key) || { count: 0, resetAt: now + options.windowMs };

    if (now > record.resetAt) {
      record.count = 0;
      record.resetAt = now + options.windowMs;
    }

    record.count++;
    store.set(key, record);

    if (record.count > options.max) {
      res.status(429).json({ error: 'Too many requests' });
      return;
    }

    next();
  };
}

module.exports = { errorHandler, rateLimiter };
