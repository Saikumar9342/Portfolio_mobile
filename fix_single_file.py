import os

file_path = "lib/screens/login_screen.dart"

if os.path.exists(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = content.replace('.withOpacity(', '.withValues(alpha: ')
    
    if content != new_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {file_path}")
    else:
        print(f"No changes for {file_path}")
else:
    print(f"File not found: {file_path}")
