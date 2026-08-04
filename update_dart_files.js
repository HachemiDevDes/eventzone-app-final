const fs = require('fs');
const path = require('path');

const stringsToTranslate = [
  "Edit Profile",
  "Saved",
  "Personal Details",
  "Full Name",
  "Job Title",
  "Company",
  "Phone Number",
  "About Me",
  "Professional Bio",
  "What I'm Looking For",
  "Industries & Interests",
  "Social Links",
  "Link",
  "Email",
  "LinkedIn",
  "Company Website",
  "Address",
  "Calendly",
  "X",
  "Instagram",
  "YouTube",
  "Threads",
  "Facebook",
  "TikTok",
  "Snapchat",
  "WhatsApp",
  "Venmo",
  "Yelp",
  "GitHub",
  "Active Links",
  "...Search areas",
  "Purchased 6 Month(s) Subscription via Chargily Pay",
  "Purchased 1 Month(s) Subscription via Chargily Pay",
  "Export Contacts",
  "All Time",
  "Today",
  "Last 15 Days",
  "Organisateur",
  "E-Commerce",
  "Client Eventzone"
];

function processFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  let content = fs.readFileSync(filePath, 'utf8');
  let changed = false;

  stringsToTranslate.forEach(str => {
    const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    
    const doubleQuoteRegex = new RegExp('"' + escapeRegex(str) + '"(?!\\.tr\\(\\))', 'g');
    if (doubleQuoteRegex.test(content)) {
      content = content.replace(doubleQuoteRegex, '"' + str + '".tr()');
      changed = true;
    }
    
    const singleQuoteRegex = new RegExp("'" + escapeRegex(str) + "'(?!\\.tr\\(\\))", 'g');
    if (singleQuoteRegex.test(content)) {
      content = content.replace(singleQuoteRegex, "'" + str + "'.tr()");
      changed = true;
    }
  });

  if (changed) {
    if (!content.includes("import 'package:easy_localization/easy_localization.dart';")) {
      content = "import 'package:easy_localization/easy_localization.dart';\n" + content;
    }
    fs.writeFileSync(filePath, content);
    console.log(filePath + ' updated with .tr() calls');
  }
}

function processDir(dir) {
  const items = fs.readdirSync(dir);
  for (const item of items) {
    const fullPath = path.join(dir, item);
    if (fs.statSync(fullPath).isDirectory()) {
      processDir(fullPath);
    } else if (fullPath.endsWith('.dart')) {
      processFile(fullPath);
    }
  }
}

processDir('lib');
