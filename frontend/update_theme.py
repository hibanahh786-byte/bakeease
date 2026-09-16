import os
import glob

# Mapping of old strings to new strings
replacements = {
    '0xFF5C3D32': '0xFF4A3022',      # Old Dark Coffee -> New Chocolate Brown
    '0xFF7EB2D8': '0xFFFF9EBB',      # Old Blue -> New Strawberry Pink
    '0xFFD4A373': '0xFFF3E5AB',      # Old Latte -> New Buttercream Yellow
    '0xFFFAF4EE': '0xFFFFF8F5',      # Old Beige -> New Cream
    'GoogleFonts.poppins': 'GoogleFonts.quicksand' # Old Body Font -> New Body Font
}

base_dir = r"C:\Users\HIBANA\OneDrive\Documents\BakeEase\frontend\lib"

# Recursively find all .dart files
dart_files = glob.glob(os.path.join(base_dir, '**', '*.dart'), recursive=True)

for file_path in dart_files:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    modified = False
    for old_txt, new_txt in replacements.items():
        if old_txt in content:
            content = content.replace(old_txt, new_txt)
            modified = True
            
    if modified:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {file_path}")

print("Theme update complete.")
