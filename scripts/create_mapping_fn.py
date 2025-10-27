import json
import os
import argparse
import numpy as np
from sklearn.model_selection import train_test_split

REFERENCE_DATA = [
    {
        "room": "I115",
        "gps": [49.22767439612417, 16.597031194295507],
        "x_y": [0, 55],
        "direction": "corner" 
    },
    {
        "room": "C130",
        "gps": [49.22691920198089, 16.596089040568025],
        "x_y": [241.0, 519.0],
        "direction": "corner",
    },
    {
        "room": "E105",
        "gps": [49.22692448157543, 16.59755397185376],
        "x_y": [475.0, 115.0],  
        "direction": "corner",
    },
    {
        "room": "E106",
        "gps": [49.226752840180126, 16.597663451815837],
        "x_y": [543.0, 45.0],  
        "direction": "corner",
    },
    {
        "room": "D105",
        "gps": [49.22615388822485, 16.597178449544025],
        "x_y": [719.0, 346.0],
        "direction": "top_corner",
    },
    {
        "room": "A118",
        "gps": [49.22682795707265, 16.5962636863341],
        "x_y": [305.0, 484.0],
        "direction": "inner_corner",
    },
    {
        "room": "F119",
        "gps": [49.22690011123387, 16.59705557534346],
        "x_y": [377.0, 210.0],
        "direction": "corner",
    },
]


parser = argparse.ArgumentParser(description="Create a mapping function from JSON data.")
parser.add_argument('--input_json', type=str, required=True, help='Path to the input JSON file.')
parser.add_argument('--output_json', type=str, required=True, help='Path to the output JSON file.')
args = parser.parse_args()

def read_json_data(file_path):
    """Reads JSON data from a file and returns it as a Python object."""
    with open(file_path, 'r') as file:
        data = json.load(file)
    return data

def write_json_data(file_path, data):
    """Writes Python object as JSON data to a file."""
    with open(file_path, 'w') as file:
        json.dump(data, file, indent=4)

def gps_to_xy(lat, lon, A):
        return (np.array([lat, lon, 1]) @ A).tolist()

def xy_to_gps(x, y, A):
    return (np.array([x, y, 1]) @ A).tolist()

def learn():

    gps = np.array([d["gps"] for d in REFERENCE_DATA])
    xy  = np.array([d["x_y"] for d in REFERENCE_DATA])
    rooms = np.array([d["room"] for d in REFERENCE_DATA])

    train_idx, test_idx = train_test_split(np.arange(len(REFERENCE_DATA)),
                                        test_size=TEST_SIZE,
                                        random_state=RANDOM_SEED)

    gps_train, xy_train = gps[train_idx], xy[train_idx]
    gps_test, xy_test = gps[test_idx], xy[test_idx]
    rooms_test = rooms[test_idx]

    X_gps = np.hstack([gps_train, np.ones((gps_train.shape[0], 1))])
    A_gps2xy, _, _, _ = np.linalg.lstsq(X_gps, xy_train, rcond=None)

    X_xy = np.hstack([xy_train, np.ones((xy_train.shape[0], 1))])
    A_xy2gps, _, _, _ = np.linalg.lstsq(X_xy, gps_train, rcond=None)

    

    for i, room in enumerate(rooms_test):
        gps_sample = gps_test[i]
        xy_sample  = xy_test[i]

        pred_xy = gps_to_xy(*gps_sample, A_gps2xy)
        pred_gps = xy_to_gps(*xy_sample, A_xy2gps)

        err_xy  = np.linalg.norm(np.array(pred_xy) - xy_sample)
        err_gps = np.linalg.norm(np.array(pred_gps) - gps_sample)

        print(f"\n🧭 Room: {room}")
        print("-" * 50)
        print("GPS → XY:")
        print("  True XY:", xy_sample)
        print("  Pred XY:", [round(v, 2) for v in pred_xy])
        print(f"  XY Error: {err_xy:.2f} map units")

        print("\nXY → GPS:")
        print("  True GPS:", gps_sample)
        print("  Pred GPS:", [round(v, 8) for v in pred_gps])
        print(f"  GPS Error: {err_gps:.8f} degrees")

    # --- Optional: Average errors if multiple test samples ---
    if len(gps_test) > 1:
        total_xy_error = np.mean([np.linalg.norm(gps_to_xy(*gps_test[i], A_gps2xy) - xy_test[i]) for i in range(len(gps_test))])
        total_gps_error = np.mean([np.linalg.norm(xy_to_gps(*xy_test[i], A_xy2gps) - gps_test[i]) for i in range(len(gps_test))])
        print("\n📊 Average Errors:")
        print(f"  Mean XY Error: {total_xy_error:.2f}")
        print(f"  Mean GPS Error: {total_gps_error:.8f}")
    return A_gps2xy, A_xy2gps




def mapping_fn(json_data):
    A_gps2xy, A_xy2gps = learn()

    new_data = []
    for entry in json_data:
        assert isinstance(entry, dict), "Each entry must be a dictionary."
        assert len(entry) == 1, "Each dictionary must contain exactly one key-value pair."

        instance_name = list(entry.keys())[0]
        instance_data = entry[instance_name]
        coords = instance_data.get("coords", [])
        # if str(instance_name) not in [ref["room"] for ref in REFERENCE_DATA]:
            # continue
        gps_coords = []
        for coord in coords:
            x, y = coord
            lat, long = xy_to_gps(x, y, A_xy2gps)
            gps_coords.append([lat, long])
        instance_data["gps_coords"] = gps_coords
        new_dict = {instance_name: instance_data}
        # xy_current = [ref["x_y"] for ref in REFERENCE_DATA if ref["room"] == str(instance_name)][0]
        # if len(xy_current) == 2:
        #     continue
        # print(instance_name, coords)
        new_data.append(new_dict)
    return new_data


if __name__ == "__main__":
    TEST_SIZE = 1
    RANDOM_SEED = 20

    args = parser.parse_args()

    input_data = read_json_data(args.input_json)
    output_data = mapping_fn(input_data)
    write_json_data(args.output_json, output_data)