import json

# Load the merged data
with open('data/parsed_data/maps_data_merged.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Collect all room entries by ID
room_dict = {}
for entry in data:
    if isinstance(entry, dict) and entry:
        room_id = list(entry.keys())[0]
        room_data = entry[room_id]
        if room_id not in room_dict:
            room_dict[room_id] = []
        room_dict[room_id].append(room_data)

# Find duplicates
duplicates = {rid: entries for rid, entries in room_dict.items() if len(entries) > 1}

print(f"Found {len(duplicates)} duplicate room IDs\n")
print("=" * 80)

# Analyze first 5 duplicates in detail
count = 0
for room_id, entries in sorted(duplicates.items()):
    if count >= 5:
        break
    if room_id:  # Skip empty string
        print(f"\nRoom ID: {room_id} ({len(entries)} occurrences)")
        for i, entry in enumerate(entries[:2], 1):
            print(f"  Entry {i}:")
            print(f"    Floor: {entry.get('floor_no', 'N/A')}")
            print(f"    Title: {entry.get('title', 'N/A')[:50]}")
            print(f"    Has coords: {bool(entry.get('coords'))}")
            print(f"    Has GPS coords: {bool(entry.get('gps_coords'))}")
            if entry.get('coords'):
                print(f"    Coords count: {len(entry.get('coords', []))}")
            if entry.get('gps_coords'):
                print(f"    GPS coords count: {len(entry.get('gps_coords', []))}")
        count += 1

print("\n" + "=" * 80)
print(f"\nSummary:")
print(f"  Total entries in file: {len(data)}")
print(f"  Unique room IDs: {len(room_dict)}")
print(f"  Duplicate room IDs: {len(duplicates)}")
print(f"  Empty string entries: {len(room_dict.get('', []))}")

