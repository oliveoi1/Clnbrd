from PIL import Image, ImageDraw, ImageFont
import os

def create_dmg_background():
    # DMG window dimensions
    width, height = 600, 400
    
    # Create image with gradient background
    img = Image.new('RGB', (width, height), color='#ffffff')
    draw = ImageDraw.Draw(img)
    
    # Create a subtle gradient from top to bottom
    for y in range(height):
        # Light blue to white gradient
        r = int(248 + (y / height) * 7)  # 248 to 255
        g = int(250 + (y / height) * 5)  # 250 to 255
        b = int(255)  # Keep blue constant
        color = (r, g, b)
        draw.line([(0, y), (width, y)], fill=color)
    
    # Add subtle border
    draw.rectangle([0, 0, width-1, height-1], outline='#d0d0d0', width=2)
    
    # Add some decorative elements
    # Top section with app name
    draw.rectangle([20, 20, width-20, 80], fill='#f8f9fa', outline='#e9ecef')
    
    # Try to add text (if font is available)
    try:
        # Try to use system font
        font_large = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
        font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
        
        # App title
        draw.text((40, 35), "Clnbrd", fill='#2c3e50', font=font_large)
        draw.text((40, 60), "Professional Clipboard Cleaning for macOS", fill='#7f8c8d', font=font_small)
        
    except:
        # Fallback: simple text without custom font
        draw.text((40, 35), "Clnbrd", fill='#2c3e50')
        draw.text((40, 60), "Professional Clipboard Cleaning for macOS", fill='#7f8c8d')
    
    # Add instruction text
    draw.text((40, height-60), "Drag Clnbrd to Applications to install", fill='#34495e')
    
    # Add some decorative dots
    for i in range(5):
        x = 100 + i * 80
        y = height - 30
        draw.ellipse([x, y, x+6, y+6], fill='#bdc3c7')
    
    return img

# Create and save the background
background = create_dmg_background()
background.save('${mountpoint}/.background/background.png', 'PNG')
print("Background image created successfully!")
