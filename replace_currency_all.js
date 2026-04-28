const fs = require('fs');
const glob = require('fs/promises'); // Just using fs

function walk(dir, done) {
  let results = [];
  fs.readdir(dir, function(err, list) {
    if (err) return done(err);
    var pending = list.length;
    if (!pending) return done(null, results);
    list.forEach(function(file) {
      file = dir + '/' + file;
      fs.stat(file, function(err, stat) {
        if (stat && stat.isDirectory()) {
          walk(file, function(err, res) {
            results = results.concat(res);
            if (!--pending) done(null, results);
          });
        } else {
          results.push(file);
          if (!--pending) done(null, results);
        }
      });
    });
  });
};

walk('./lib', (err, files) => {
    if (err) throw err;
    let anyUpdates = false;
    files.filter(f => f.endsWith('.dart')).forEach(fullPath => {
        let content = fs.readFileSync(fullPath, 'utf8');
        
        // Replace \ with ?number*55
        let replaced = content.replace(/\\\$\s*([\d,]+(\.\d{2})?)/g, (match, amountStr) => {
            let stripped = amountStr.replace(/,/g, '');
            let num = parseFloat(stripped);
            if (isNaN(num)) return match;
            
            let newAmount = Math.round(num * 55);
            return '?' + newAmount.toLocaleString('en-US');
        });

        // Replace literal string USD with PHP
        replaced = replaced.replace(/\bUSD\b/g, 'PHP');
        
        if (content !== replaced) {
            fs.writeFileSync(fullPath, replaced, 'utf8');
            console.log('Updated ' + fullPath);
            anyUpdates = true;
        }
    });

    if(!anyUpdates) console.log('No files needed updating.');
});

