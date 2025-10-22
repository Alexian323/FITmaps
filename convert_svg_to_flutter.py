#!/usr/bin/env python3
"""
Convert SVG files to Flutter-compatible format
This script extracts the building layout and creates a data structure for Flutter
"""

import os
import re
import json

def extract_room_data_from_svg(svg_file):
    """Extract room data from SVG file"""
    rooms = []
    
    try:
        with open(svg_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extract room rectangles
        rect_pattern = r'<rect[^>]*x="([^"]*)"[^>]*y="([^"]*)"[^>]*width="([^"]*)"[^>]*height="([^"]*)"[^>]*fill="([^"]*)"[^>]*/?>'
        rect_matches = re.findall(rect_pattern, content)
        
        for match in rect_matches:
            rooms.append({
                'type': 'rect',
                'x': float(match[0]) if match[0] else 0,
                'y': float(match[1]) if match[1] else 0,
                'width': float(match[2]) if match[2] else 0,
                'height': float(match[3]) if match[3] else 0,
                'fill': match[4] if match[4] else '#cccccc'
            })
        
        # Extract room polygons
        polygon_pattern = r'<polygon[^>]*points="([^"]*)"[^>]*fill="([^"]*)"[^>]*/?>'
        polygon_matches = re.findall(polygon_pattern, content)
        
        for match in polygon_matches:
            points = match[0].split(' ')
            point_list = []
            for point in points:
                coords = point.split(',')
                if len(coords) == 2:
                    point_list.append({
                        'x': float(coords[0]),
                        'y': float(coords[1])
                    })
            
            rooms.append({
                'type': 'polygon',
                'points': point_list,
                'fill': match[1] if match[1] else '#cccccc'
            })
        
        return rooms
        
    except Exception as e:
        print(f"Error processing {svg_file}: {e}")
        return []

def process_all_svgs():
    """Process all SVG files and create Flutter data"""
    svg_folder = "assets/floors"
    output_file = "lib/data/building_layouts.dart"
    
    if not os.path.exists(svg_folder):
        print(f"SVG folder {svg_folder} not found!")
        return
    
    # Create output directory
    os.makedirs("lib/data", exist_ok=True)
    
    # Process each SVG file
    floor_data = {}
    
    for filename in os.listdir(svg_folder):
        if filename.endswith('.svg'):
            floor_name = filename.replace('.svg', '')
            svg_path = os.path.join(svg_folder, filename)
            rooms = extract_room_data_from_svg(svg_path)
            floor_data[floor_name] = rooms
            print(f"Processed {filename}: {len(rooms)} rooms")
    
    # Generate Flutter Dart file
    dart_content = '''// Auto-generated building layout data
// Generated from SVG files

class BuildingLayout {
  final String floor;
  final List<RoomData> rooms;
  
  BuildingLayout({required this.floor, required this.rooms});
}

class RoomData {
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final List<Map<String, double>>? points;
  final String fill;
  
  RoomData({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.points,
    required this.fill,
  });
}

final Map<String, BuildingLayout> buildingLayouts = {
'''
    
    for floor_name, rooms in floor_data.items():
        dart_content += f'  "{floor_name}": BuildingLayout(\n'
        dart_content += f'    floor: "{floor_name}",\n'
        dart_content += f'    rooms: [\n'
        
        for room in rooms:
            dart_content += f'      RoomData(\n'
            dart_content += f'        type: "{room["type"]}",\n'
            dart_content += f'        x: {room["x"]},\n'
            dart_content += f'        y: {room["y"]},\n'
            dart_content += f'        width: {room["width"]},\n'
            dart_content += f'        height: {room["height"]},\n'
            
            if room["type"] == "polygon" and room.get("points"):
                dart_content += f'        points: [\n'
                for point in room["points"]:
                    dart_content += f'          {{"x": {point["x"]}, "y": {point["y"]}}},\n'
                dart_content += f'        ],\n'
            
            dart_content += f'        fill: "{room["fill"]}",\n'
            dart_content += f'      ),\n'
        
        dart_content += f'    ],\n'
        dart_content += f'  ),\n'
    
    dart_content += '};\n'
    
    # Write to file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(dart_content)
    
    print(f"Generated {output_file}")
    print("Building layouts converted successfully!")

if __name__ == "__main__":
    process_all_svgs()

