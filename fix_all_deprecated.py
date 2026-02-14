import os

root_dir = r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib"

for subdir, dirs, files in os.walk(root_dir):
    for file in files:
        if file.endswith(".dart"):
            file_path = os.path.join(subdir, file)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                new_content = content.replace('.withOpacity(', '.withValues(alpha: ')
                
                if content != new_content:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated {file_path}")
                else:
                    # check for debug
                    if 'home_screen' in file_path:
                        print(f"Checked {file_path}, no 'withOpacity' found or already replaced.")
                        if '.withOpacity(' in content:
                             print(f"WARNING: .withOpacity( found in {file_path} but replace failed?")
            except Exception as e:
                print(f"Error processing {file_path}: {e}")
