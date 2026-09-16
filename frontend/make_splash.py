from PIL import Image

img = Image.open('assets/images/logo.png')
bbox = img.getbbox()
cropped = img.crop(bbox)

w, h = cropped.size
max_dim = max(w, h)
new_size = int(max_dim * 1.2)

new_img = Image.new('RGBA', (new_size, new_size), (0,0,0,0))
offset = ((new_size - w) // 2, (new_size - h) // 2)
new_img.paste(cropped, offset)

new_img.save('assets/images/splash_logo.png')
print("Saved splash_logo.png")
