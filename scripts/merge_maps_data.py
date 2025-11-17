"""
Merge maps_data.json and maps_data_with_gps_coords.json into a single file.
The merged file will contain both 'coords' (pixel coordinates) and 'gps_coords' (GPS coordinates).
"""

import json
import os
import argparse


def read_json_data(file_path):
    """Reads JSON data from a file and returns it as a Python object."""
    with open(file_path, 'r', encoding='utf-8') as file:
        data = json.load(file)
    return data


def write_json_data(file_path, data):
    """Writes Python object as JSON data to a file."""
    with open(file_path, 'w', encoding='utf-8') as file:
        json.dump(data, file, indent=4, ensure_ascii=False)


def merge_maps_data(maps_data_path, gps_data_path, output_path):
    """
    Merge two JSON files:
    - maps_data.json: contains 'coords' (pixel coordinates)
    - maps_data_with_gps_coords.json: contains 'gps_coords' (GPS coordinates)
    
    The merged output will have both coordinate systems for each room.
    """
    print(f"Reading {maps_data_path}...")
    maps_data = read_json_data(maps_data_path)
    
    print(f"Reading {gps_data_path}...")
    gps_data = read_json_data(gps_data_path)
    
    # Create a dictionary for quick lookup of GPS coordinates by room ID
    gps_lookup = {}
    for room_entry in gps_data:
        if isinstance(room_entry, dict):
            for room_id, room_data in room_entry.items():
                if 'gps_coords' in room_data:
                    gps_lookup[room_id] = room_data['gps_coords']
    
    print(f"Found {len(gps_lookup)} rooms with GPS coordinates")
    
    # Merge the data
    merged_data = []
    rooms_with_coords = 0
    rooms_with_gps = 0
    rooms_with_both = 0
    
    for room_entry in maps_data:
        if isinstance(room_entry, dict):
            merged_entry = {}
            for room_id, room_data in room_entry.items():
                # Start with the original room data (has 'coords')
                merged_room_data = room_data.copy()
                
                # Add GPS coordinates if available
                if room_id in gps_lookup:
                    merged_room_data['gps_coords'] = gps_lookup[room_id]
                    rooms_with_gps += 1
                    if 'coords' in merged_room_data:
                        rooms_with_both += 1
                elif 'coords' in merged_room_data:
                    rooms_with_coords += 1
                
                merged_entry[room_id] = merged_room_data
            
            merged_data.append(merged_entry)
    
    print(f"\nMerge Summary:")
    print(f"  Total rooms: {len(merged_data)}")
    print(f"  Rooms with pixel coords only: {rooms_with_coords}")
    print(f"  Rooms with GPS coords: {rooms_with_gps}")
    print(f"  Rooms with both coords: {rooms_with_both}")
    
    # Write merged data
    print(f"\nWriting merged data to {output_path}...")
    write_json_data(output_path, merged_data)
    print("Merge completed successfully!")
    
    return merged_data


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Merge maps_data.json and maps_data_with_gps_coords.json"
    )
    parser.add_argument(
        '--maps_data',
        type=str,
        default='data/parsed_data/maps_data.json',
        help='Path to maps_data.json (default: data/parsed_data/maps_data.json)'
    )
    parser.add_argument(
        '--gps_data',
        type=str,
        default='data/parsed_data/maps_data_with_gps_coords.json',
        help='Path to maps_data_with_gps_coords.json (default: data/parsed_data/maps_data_with_gps_coords.json)'
    )
    parser.add_argument(
        '--output',
        type=str,
        default='data/parsed_data/maps_data_merged.json',
        help='Path to output merged JSON file (default: data/parsed_data/maps_data_merged.json)'
    )
    
    args = parser.parse_args()
    
    # Validate input files exist
    if not os.path.exists(args.maps_data):
        print(f"Error: {args.maps_data} not found!")
        exit(1)
    
    if not os.path.exists(args.gps_data):
        print(f"Error: {args.gps_data} not found!")
        exit(1)
    
    # Create output directory if it doesn't exist
    output_dir = os.path.dirname(args.output)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Perform merge
    merge_maps_data(args.maps_data, args.gps_data, args.output)

