import os
import re

def scan_files():
    dart_files = []
    for root, _, files in os.walk('lib'):
        for f in files:
            if f.endswith('.dart'):
                dart_files.append(os.path.join(root, f))
                
    string_pattern = re.compile(r'(?:Text\(\s*|hintText:\s*|labelText:\s*|tooltip:\s*)([\'"])(.*?)\1')
    
    total_strings = set()
    for filepath in dart_files:
        with open(filepath, 'r', encoding='utf-8') as file:
            content = file.read()
            # find all matches that don't end with .tr() already
            # Actually just find all matches and filter out interpolations
            matches = string_pattern.findall(content)
            for match in matches:
                text = match[1]
                if '$' not in text and '{' not in text and len(text.strip()) > 0:
                    total_strings.add(text)
                    
    print(f"Total Dart files: {len(dart_files)}")
    print(f"Total unique translatable strings found: {len(total_strings)}")
    
    with open('extracted_strings_preview.txt', 'w', encoding='utf-8') as f:
        for s in sorted(list(total_strings)):
            f.write(s + '\n')

if __name__ == '__main__':
    scan_files()
