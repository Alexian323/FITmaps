"""
Remove duplicate room entries from maps_data_merged.json.
For each duplicate room ID, keeps the entry with the most complete data
(preferring entries with both coords and gps_coords).
"""

import json
import os

def remove_duplicates(input_path, output_path=None):
    """
    Remove duplicate room entries from the JSON file.
    
    Args:
        input_path: Path to the input JSON file
        output_path: Path to save cleaned JSON (defaults to overwriting input)
    """
    if output_path is None:
        output_path = input_path
    
    print(f"Reading {input_path}...")
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    print(f"Loaded {len(data)} entries")
    
    # Track rooms by ID and keep the best entry for each
    room_dict = {}
    duplicates_found = []
    
    for entry in data:
        if isinstance(entry, dict) and entry:
            room_id = list(entry.keys())[0]
            room_data = entry[room_id]
            
            # Skip empty room IDs
            if not room_id:
                continue
            
            if room_id not in room_dict:
                room_dict[room_id] = room_data
            else:
                # Duplicate found - keep the one with more complete data
                duplicates_found.append(room_id)
                existing = room_dict[room_id]
                
                # Score entries: higher score = more complete data
                def score_entry(entry_data):
                    score = 0
                    if entry_data.get('coords'):
                        score += 1
                    if entry_data.get('gps_coords'):
                        score += 2  # GPS coords are more valuable
                    if entry_data.get('title'):
                        score += 0.5
                    return score
                
                existing_score = score_entry(existing)
                new_score = score_entry(room_data)
                
                # Keep the entry with higher score
                if new_score > existing_score:
                    room_dict[room_id] = room_data
                    print(f"  Replaced {room_id}: old score={existing_score:.1f}, new score={new_score:.1f}")
    
    # Rebuild the data structure
    cleaned_data = []
    for room_id, room_data in sorted(room_dict.items()):
        cleaned_data.append({room_id: room_data})
    
    print(f"\nRemoved {len(duplicates_found)} duplicate entries")
    print(f"Final count: {len(cleaned_data)} unique rooms")
    print(f"Removed duplicates: {sorted(set(duplicates_found))}")
    
    # Write cleaned data
    print(f"\nWriting cleaned data to {output_path}...")
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(cleaned_data, f, indent=4, ensure_ascii=False)
    
    print("Done!")
    return cleaned_data


if __name__ == "__main__":
    input_file = 'data/parsed_data/maps_data_merged.json'
    
    # Create backup first
    backup_file = 'data/parsed_data/maps_data_merged.json.backup'
    print(f"Creating backup: {backup_file}")
    import shutil
    shutil.copy2(input_file, backup_file)
    print("Backup created!\n")
    
    # Remove duplicates
    remove_duplicates(input_file)

