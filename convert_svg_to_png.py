#!/usr/bin/env python3
"""
Convert SVG files to PNG images for Flutter app
This preserves all colors and details from your original SVG files
"""

import os
from PIL import Image
import cairosvg

def convert_svg_to_png(svg_folder, output_folder):
    """Convert all SVG files in a folder to PNG"""
    
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
    
    for filename in os.listdir(svg_folder):
        if filename.endswith('.svg'):
            svg_path = os.path.join(svg_folder, filename)
            png_filename = filename.replace('.svg', '.png')
            png_path = os.path.join(output_folder, png_filename)
            
            try:
                # Convert SVG to PNG with high resolution
                cairosvg.svg2png(url=svg_path, write_to=png_path, output_width=1440, output_height=2000)
                print(f"Converted {filename} to {png_filename}")
            except Exception as e:
                print(f"Error converting {filename}: {e}")

if __name__ == "__main__":
    # Convert your SVG files
    convert_svg_to_png("assets/floors", "assets/floors_png")
    print("Conversion complete!")

