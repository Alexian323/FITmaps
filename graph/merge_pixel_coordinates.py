"""
Merge pixel coordinates from maps_data_merged.json into maps_data_full_with_floor_no_with_gps_coords.json
Intelligently matches rooms by ID and floor number
"""

import json
import os

def load_json_file(filepath):
    """Load JSON file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json_file(data, filepath):
    """Save JSON file with pretty formatting"""
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

def normalize_floor(floor_str):
    """Normalize floor number format"""
    if not floor_str:
        return None
    floor_str = str(floor_str).strip()
    # Ensure it starts with + or -
    if floor_str and not floor_str.startswith('+') and not floor_str.startswith('-'):
        # If it's just a number, add + prefix
        if floor_str.isdigit() or (floor_str.startswith('-') and floor_str[1:].isdigit()):
            return f"+{floor_str}" if not floor_str.startswith('-') else floor_str
    return floor_str

def extract_room_id_and_floor(room_key):
    """Extract room ID and floor from key"""
    if '__' in room_key:
        parts = room_key.split('__')
        room_id = parts[0]
        floor = parts[1] if len(parts) > 1 else None
        return room_id, normalize_floor(floor)
    return room_key, None

def build_room_lookup(data, use_floor_in_key=False):
    """Build a lookup dictionary for rooms"""
    lookup = {}
    
    for room_entry in data:
        if isinstance(room_entry, dict):
            for room_key, room_data in room_entry.items():
                room_id, floor_from_key = extract_room_id_and_floor(room_key)
                floor_from_data = normalize_floor(room_data.get('floor_no'))
                
                # Use floor from key if available, otherwise from data
                floor = floor_from_key or floor_from_data
                
                # Create lookup key: (room_id, floor)
                lookup_key = (room_id, floor)
                
                # Store room data with original key
                lookup[lookup_key] = {
                    'key': room_key,
                    'data': room_data,
                }
    
    return lookup

def merge_coordinates():
    """Merge pixel coordinates from old file into new file"""
    
    # File paths
    old_file = '../data/parsed_data/maps_data_merged.json'
    new_file = 'maps_data_full_with_floor_no_with_gps_coords.json'
    output_file = 'maps_data_full_with_floor_no_with_gps_coords.json'
    
    print(f"Loading old file: {old_file}")
    old_data = load_json_file(old_file)
    
    print(f"Loading new file: {new_file}")
    new_data = load_json_file(new_file)
    
    # Build lookups
    print("Building room lookups...")
    old_lookup = build_room_lookup(old_data, use_floor_in_key=False)
    new_lookup = build_room_lookup(new_data, use_floor_in_key=True)
    
    print(f"Old file: {len(old_lookup)} rooms")
    print(f"New file: {len(new_lookup)} rooms")
    
    # Statistics
    matched_count = 0
    added_coords_count = 0
    missing_coords_count = 0
    unmatched_rooms = []
    
    # Merge coordinates
    print("\nMerging pixel coordinates...")
    
    for room_entry in new_data:
        if isinstance(room_entry, dict):
            for room_key, room_data in room_entry.items():
                room_id, floor_from_key = extract_room_id_and_floor(room_key)
                floor_from_data = normalize_floor(room_data.get('floor_no'))
                floor = floor_from_key or floor_from_data
                
                # Look for matching room in old data
                lookup_key = (room_id, floor)
                
                if lookup_key in old_lookup:
                    old_room = old_lookup[lookup_key]['data']
                    old_coords = old_room.get('coords', [])
                    
                    if old_coords:
                        # Add pixel coordinates to new room data
                        room_data['coords'] = old_coords
                        matched_count += 1
                        added_coords_count += 1
                        
                        # Verify GPS coordinates match (optional check)
                        old_gps = old_room.get('gps_coords', [])
                        new_gps = room_data.get('gps_coords', [])
                        
                        if old_gps and new_gps:
                            # Check if GPS coordinates are similar (within tolerance)
                            # This is just for verification, not required
                            pass
                    else:
                        missing_coords_count += 1
                        print(f"  Warning: Room {room_key} found in old file but has no pixel coordinates")
                else:
                    # Try to find by room ID only (different floor)
                    found_by_id = False
                    for (old_id, old_floor), old_room_info in old_lookup.items():
                        if old_id == room_id:
                            old_coords = old_room_info['data'].get('coords', [])
                            if old_coords:
                                # Use coordinates from different floor as fallback
                                room_data['coords'] = old_coords
                                matched_count += 1
                                added_coords_count += 1
                                found_by_id = True
                                print(f"  Info: Room {room_key} matched by ID only (floor {old_floor} -> {floor})")
                                break
                    
                    if not found_by_id:
                        unmatched_rooms.append(room_key)
    
    # Print statistics
    print(f"\n{'='*60}")
    print("MERGE STATISTICS")
    print(f"{'='*60}")
    print(f"Total rooms in new file: {len(new_lookup)}")
    print(f"Matched rooms: {matched_count}")
    print(f"Added pixel coordinates: {added_coords_count}")
    print(f"Missing coordinates: {missing_coords_count}")
    print(f"Unmatched rooms: {len(unmatched_rooms)}")
    
    if unmatched_rooms:
        print(f"\nUnmatched rooms (first 20):")
        for room_key in unmatched_rooms[:20]:
            print(f"  - {room_key}")
        if len(unmatched_rooms) > 20:
            print(f"  ... and {len(unmatched_rooms) - 20} more")
    
    # Save merged data
    print(f"\nSaving merged data to {output_file}...")
    save_json_file(new_data, output_file)
    
    print(f"\n✅ Successfully merged pixel coordinates!")
    print(f"   Output file: {output_file}")
    
    # Verify the merge
    print(f"\nVerifying merged file...")
    verify_data = load_json_file(output_file)
    rooms_with_coords = 0
    rooms_with_gps = 0
    rooms_with_both = 0
    
    for room_entry in verify_data:
        if isinstance(room_entry, dict):
            for room_key, room_data in room_entry.items():
                has_coords = bool(room_data.get('coords'))
                has_gps = bool(room_data.get('gps_coords'))
                
                if has_coords:
                    rooms_with_coords += 1
                if has_gps:
                    rooms_with_gps += 1
                if has_coords and has_gps:
                    rooms_with_both += 1
    
    print(f"Rooms with pixel coordinates: {rooms_with_coords}")
    print(f"Rooms with GPS coordinates: {rooms_with_gps}")
    print(f"Rooms with both: {rooms_with_both}")

if __name__ == "__main__":
    merge_coordinates()





