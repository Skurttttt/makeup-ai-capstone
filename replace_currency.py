import os
import re

def convert_currency():
    lib_path = './lib'
    for root, dirs, files in os.walk(lib_path):
        for file in files:
            if not file.endswith('.dart'): continue
            
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                
            def replace_match(match):
                num_str = match.group(1).replace(',', '')
                try:
                    num = float(num_str)
                    peso = round(num * 55)
                    return f"₱{peso:,}"
                except:
                    return match.group(0)

            # Replace \$\d+,\d+ or \$\d+.\d+
            # We look for literal dollars that are escaped: \$
            # Wait, in dart source code, literal dollar is written as `\$` inside strings.
            # But the regex `\\\$([\d,]+(\.\d{2})?)` in python targets `\$` followed by digits.
            new_content = re.sub(r'\\\$([\d,]+(?:\.\d{2})?)', replace_match, content)
            
            new_content = re.sub(r'\bUSD\b', 'PHP', new_content)
            
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"Updated {filepath}")

convert_currency()
