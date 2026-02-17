from PIL import Image
import os

def rotate_image():
    input_path = 'assets/navigation_arrow.png'
    output_path = 'assets/app_icon.png'

    try:
        # Open the image
        img = Image.open(input_path)
        
        # Rotate 45 degrees
        # expand=True ensures the corners aren't clipped
        rotated_img = img.rotate(-45, expand=True, resample=Image.BICUBIC) 
        
        # The rotation might create a larger canvas. 
        # For an app icon, we generally want it square. 
        # Let's crop/resize or center it on a square canvas if needed, 
        # but for now, just saving the rotated version is a good start. 
        # Actually, let's make sure it's square.
        
        max_dim = max(rotated_img.size)
        square_img = Image.new('RGBA', (max_dim, max_dim), (0, 0, 0, 0))
        offset = ((max_dim - rotated_img.size[0]) // 2, (max_dim - rotated_img.size[1]) // 2)
        square_img.paste(rotated_img, offset)
        
        # Save the result
        square_img.save(output_path)
        print(f"Successfully created {output_path}")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    rotate_image()
