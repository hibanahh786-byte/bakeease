import os
from PIL import Image

# Use the original logo
img = Image.open('assets/images/logo.png')
bbox = img.getbbox()
cropped = img.crop(bbox)

# Target sizes for ~300dp width
# cropped aspect ratio is 485x695 (w x h)
# If width is 300dp, height will be 300 * (695/485) = 430dp

densities = {
    'mdpi': 1,
    'hdpi': 1.5,
    'xhdpi': 2,
    'xxhdpi': 3,
    'xxxhdpi': 4,
}

base_width = 300
base_height = int(base_width * (cropped.height / cropped.width))

for density, mult in densities.items():
    target_w = int(base_width * mult)
    target_h = int(base_height * mult)
    
    resized = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    # Save directly to the android drawable folder
    path = f"android/app/src/main/res/drawable-{density}/splash.png"
    if os.path.exists(os.path.dirname(path)):
        resized.save(path)
        print(f"Saved {path} with size {target_w}x{target_h}")

print("Done generating large splash screens!")
