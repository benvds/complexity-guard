// Fixture: Nested callback patterns
// Purpose: Test legacy callback-style async patterns (error-first callbacks, nested closures)
// Expected complexity: processQueue ~8, processHighPriority ~2, nesting ~5

function processQueue(queue, config, callback) {
  const results = [];
  let processed = 0;

  queue.forEach(function(item, index) {
    setTimeout(function() {
      try {
        if (item.priority > config.threshold) {
          processHighPriority(item, function(err, result) {
            if (err) {
              if (config.strict) {
                callback(err);
                return;
              }
              results.push({ item, error: err.message });
            } else {
              results.push({ item, result });
            }
            processed++;
            if (processed === queue.length) {
              callback(null, results);
            }
          });
        } else {
          results.push({ item, result: 'skipped' });
          processed++;
          if (processed === queue.length) {
            callback(null, results);
          }
        }
      } catch (e) {
        callback(e);
      }
    }, index * config.delay);
  });
}

function processHighPriority(item, callback) {
  // Simulated async processing
  if (!item.data) {
    callback(new Error('No data'));
    return;
  }
  callback(null, { processed: true, id: item.id });
}

module.exports = { processQueue, processHighPriority };
