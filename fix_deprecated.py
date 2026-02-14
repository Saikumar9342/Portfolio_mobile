import os

files = [
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\widgets\success_dialog.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\widgets\primary_button.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\widgets\gradient_card.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\widgets\custom_text_field.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\widgets\action_dialog.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\theme\app_theme.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\screens\skill_detail_screen.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\screens\resume_upload_screen.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\screens\skills_manager_screen.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\screens\projects_screen.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\screens\profile_screen.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\screens\login_screen.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\screens\home_screen.dart",
    r"e:\2. Projects\8. Portfolio\Portfolio Mobile\lib\main.dart"
]

for file_path in files:
    try:
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
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
