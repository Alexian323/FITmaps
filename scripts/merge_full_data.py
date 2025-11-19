"""
Merge missing rooms from maps_data_full.json into maps_data_merged.json.
The full file has doors and additional rooms that need to be added to the merged file.
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


def merge_full_data_into_merged(merged_path, full_path, output_path):
    """
    Merge missing rooms from maps_data_full.json into maps_data_merged.json.
    Preserves GPS coordinates from merged file where they exist.
    """
    print(f"Reading {merged_path}...")
    merged_data = read_json_data(merged_path)
    
    print(f"Reading {full_path}...")
    full_data = read_json_data(full_path)
    
    # Create a lookup of existing rooms in merged data (by room ID)
    merged_rooms = {}
    for room_entry in merged_data:
        if isinstance(room_entry, dict):
            for room_id, room_data in room_entry.items():
                merged_rooms[room_id] = room_data
    
    print(f"Found {len(merged_rooms)} rooms in merged file")
    
    # Create a lookup of all rooms in full data
    full_rooms = {}
    for room_entry in full_data:
        if isinstance(room_entry, dict):
            for room_id, room_data in room_entry.items():
                full_rooms[room_id] = room_data
    
    print(f"Found {len(full_rooms)} rooms in full file")
    
    # Find missing rooms and add them
    missing_rooms = {}
    rooms_added = 0
    rooms_updated = 0
    
    for room_id, room_data in full_rooms.items():
        if room_id not in merged_rooms:
            # Room is missing - add it
            missing_rooms[room_id] = room_data
            rooms_added += 1
        else:
            # Room exists - check if we need to update title or other fields
            merged_room = merged_rooms[room_id]
            full_room = room_data
            
            # Update title if full file has more complete data (e.g., lecturer names)
            if 'title' in full_room and full_room['title'] != merged_room.get('title', ''):
                # Check if full title is longer/more complete
                if len(full_room['title']) > len(merged_room.get('title', '')):
                    merged_rooms[room_id]['title'] = full_room['title']
                    rooms_updated += 1
    
    print(f"\nFound {rooms_added} missing rooms to add")
    print(f"Updated {rooms_updated} existing rooms with more complete data")
    
    # Add missing rooms to merged data
    for room_id, room_data in missing_rooms.items():
        # Create a new entry for the missing room
        merged_data.append({room_id: room_data})
    
    # Sort merged data by room ID for consistency (optional)
    # merged_data.sort(key=lambda x: list(x.keys())[0] if x else '')
    
    print(f"\nFinal merged file will have {len(merged_data)} room entries")
    
    # Write merged data
    print(f"\nWriting updated merged data to {output_path}...")
    write_json_data(output_path, merged_data)
    print("Merge completed successfully!")
    
    return merged_data


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Merge missing rooms from maps_data_full.json into maps_data_merged.json"
    )
    parser.add_argument(
        '--merged',
        type=str,
        default='data/parsed_data/maps_data_merged.json',
        help='Path to maps_data_merged.json (default: data/parsed_data/maps_data_merged.json)'
    )
    parser.add_argument(
        '--full',
        type=str,
        default='data/parsed_data/maps_data_full.json',
        help='Path to maps_data_full.json (default: data/parsed_data/maps_data_full.json)'
    )
    parser.add_argument(
        '--output',
        type=str,
        default='data/parsed_data/maps_data_merged.json',
        help='Path to output merged JSON file (default: data/parsed_data/maps_data_merged.json)'
    )
    
    args = parser.parse_args()
    
    # Validate input files exist
    if not os.path.exists(args.merged):
        print(f"Error: {args.merged} not found!")
        exit(1)
    
    if not os.path.exists(args.full):
        print(f"Error: {args.full} not found!")
        exit(1)
    
    # Create output directory if it doesn't exist
    output_dir = os.path.dirname(args.output)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Perform merge
    merge_full_data_into_merged(args.merged, args.full, args.output)

