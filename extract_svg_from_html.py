#!/usr/bin/env python3
"""
Extract SVG content from HTML files and create Flutter-compatible data
"""

import os
import re
import json

def extract_svg_from_html(html_file):
    """Extract SVG content from HTML file"""
    try:
        with open(html_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extract the SVG element
        svg_match = re.search(r'<svg[^>]*>.*?</svg>', content, re.DOTALL)
        if svg_match:
            return svg_match.group(0)
        
        return None
    except Exception as e:
        print(f"Error processing {html_file}: {e}")
        return None

def extract_room_data_from_html(html_file):
    """Extract room data from HTML file"""
    try:
        with open(html_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        rooms = []
        
        # Extract room groups with onclick attributes
        room_pattern = r'<g[^>]*onclick="([^"]*)"[^>]*>.*?</g>'
        room_matches = re.findall(room_pattern, content, re.DOTALL)
        
        for onclick in room_matches:
            # Extract room ID from onclick
            room_id_match = re.search(r"'([^']+)'", onclick)
            if room_id_match:
                room_id = room_id_match.group(1)
                
                # Find the polygon/rect for this room
                room_section = re.search(f'<g[^>]*onclick="{re.escape(onclick)}"[^>]*>(.*?)</g>', content, re.DOTALL)
                if room_section:
                    room_content = room_section.group(1)
                    
                    # Extract polygon
                    polygon_match = re.search(r'<polygon[^>]*points="([^"]*)"[^>]*/?>', room_content)
                    if polygon_match:
                        points = polygon_match.group(1).split(' ')
                        point_list = []
                        for point in points:
                            coords = point.split(',')
                            if len(coords) == 2:
                                point_list.append({
                                    'x': float(coords[0]),
                                    'y': float(coords[1])
                                })
                        
                        rooms.append({
                            'id': room_id,
                            'type': 'polygon',
                            'points': point_list,
                            'fill': '#cccccc'  # Default color
                        })
                    
                    # Extract rectangle
                    rect_match = re.search(r'<rect[^>]*x="([^"]*)"[^>]*y="([^"]*)"[^>]*width="([^"]*)"[^>]*height="([^"]*)"[^>]*/?>', room_content)
                    if rect_match:
                        rooms.append({
                            'id': room_id,
                            'type': 'rect',
                            'x': float(rect_match.group(1)) if rect_match.group(1) else 0,
                            'y': float(rect_match.group(2)) if rect_match.group(2) else 0,
                            'width': float(rect_match.group(3)) if rect_match.group(3) else 0,
                            'height': float(rect_match.group(4)) if rect_match.group(4) else 0,
                            'fill': '#cccccc'  # Default color
                        })
        
        return rooms
        
    except Exception as e:
        print(f"Error processing {html_file}: {e}")
        return []

def process_html_files():
    """Process all HTML files and create Flutter data"""
    html_folder = "data/raw_htmls"
    
    if not os.path.exists(html_folder):
        print(f"HTML folder {html_folder} not found!")
        return
    
    # Create output directory
    os.makedirs("lib/data", exist_ok=True)
    
    # Process each HTML file
    floor_data = {}
    
    for filename in os.listdir(html_folder):
        if filename.endswith('.html') and 'FIT_Maps_floor_' in filename:
            # Extract floor number
            floor_match = re.search(r'floor_([+-]?\d+)', filename)
            if floor_match:
                floor_num = floor_match.group(1)
                floor_name = f"Floor {floor_num}"
                
                html_path = os.path.join(html_folder, filename)
                rooms = extract_room_data_from_html(html_path)
                floor_data[floor_name] = rooms
                print(f"Processed {filename}: {len(rooms)} rooms")
    
    # Generate Flutter Dart file
    dart_content = '''// Auto-generated building layout data
// Generated from HTML files

class BuildingLayout {
  final String floor;
  final List<RoomData> rooms;
  
  BuildingLayout({required this.floor, required this.rooms});
}

class RoomData {
  final String id;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final List<Map<String, double>>? points;
  final String fill;
  
  RoomData({
    required this.id,
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
            dart_content += f'        id: "{room["id"]}",\n'
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
    output_file = "lib/data/building_layouts.dart"
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(dart_content)
    
    print(f"Generated {output_file}")
    print("Building layouts converted successfully!")
    
    # Also create a simple JSON file for easier debugging
    json_file = "lib/data/building_layouts.json"
    with open(json_file, 'w', encoding='utf-8') as f:
        json.dump(floor_data, f, indent=2)
    
    print(f"Generated {json_file}")

if __name__ == "__main__":
    process_html_files()

