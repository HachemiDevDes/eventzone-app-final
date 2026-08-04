const fs = require('fs');
const path = require('path');

function findTrCalls(dir, files = []) {
  const items = fs.readdirSync(dir);
  for (const item of items) {
    const fullPath = path.join(dir, item);
    if (fs.statSync(fullPath).isDirectory()) {
      findTrCalls(fullPath, files);
    } else if (fullPath.endsWith('.dart')) {
      const content = fs.readFileSync(fullPath, 'utf8');
      const regex = /(?:\"([^\"]+)\"|\'([^\']+)\')\.tr\(\)/g;
      let match;
      while ((match = regex.exec(content)) !== null) {
        files.push(match[1] || match[2]);
      }
    }
  }
  return files;
}

const keys = [...new Set(findTrCalls('lib'))];
const en = JSON.parse(fs.readFileSync('assets/translations/en.json'));
const fr = JSON.parse(fs.readFileSync('assets/translations/fr.json'));
const ar = JSON.parse(fs.readFileSync('assets/translations/ar.json'));

const missingEn = keys.filter(k => !en[k]);
const missingFr = keys.filter(k => !fr[k]);
const missingAr = keys.filter(k => !ar[k]);

console.log('Missing in EN:', JSON.stringify(missingEn, null, 2));
console.log('Missing in FR:', JSON.stringify(missingFr, null, 2));
console.log('Missing in AR:', JSON.stringify(missingAr, null, 2));
