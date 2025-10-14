import os
import json
from bs4 import BeautifulSoup
import argparse

parser = argparse.ArgumentParser(description="Extract room data from map SVG HTML file")
parser.add_argument("-i", "--input", default="data/raw_htmls", help="Path to the input HTML folder")
parser.add_argument("-o", "--save_path", default="data/parsed_data/maps_data.json", help="Path to the output JSON file")

def read_html_data(file_path):
    soups = {}
    for filename in os.listdir(file_path):
        assert filename.endswith(".html"), "Input folder must contain only HTML files."
        with open(os.path.join(file_path, filename), "r", encoding="utf-8") as f:
            floor_no = filename.split(".")[0].split("_")[-1]
            soup = BeautifulSoup(f, "html.parser")
        soups[floor_no] = soup
    return soups

def save_json(data, save_path):
    os.makedirs(os.path.dirname(save_path), exist_ok=True)
    with open(save_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)

def extract_rooms(soups):
    rooms = []
    for floor_no, soup in soups.items():
        rooms_group = soup.find("g", {"id": "rooms"})
        for g in rooms_group.find_all("g", recursive=False):
            if g.get("onclick", "") != "":
                link = g.get("onclick", "").split("'")[1]
            title = g.find("title").text.strip()
            room_tag = ""
            if "wheelchair" in title.lower():
                title = title.replace("\nnot wheelchair accessible", "").strip()
                room_tag = " not wheelchair accessible"
            shape = g.find(["polygon", "rect"])
            assert shape is not None
            room_id = shape.get("id", "")
            coords = []

            if shape.name == "polygon":
                raw = shape.get("points", "").strip().split()
                coords = [tuple(map(float, p.split(","))) for p in raw if "," in p]
            elif shape.name == "rect":
                x, y = float(shape["x"]), float(shape["y"])
                w, h = float(shape["width"]), float(shape["height"])
                coords = [(x, y), (x+w, y), (x+w, y+h), (x, y+h)]

            rooms.append({
                room_id: {
                    "title": title,
                    "onclick": link,
                    "floor_no": floor_no,
                    "room_tag": room_tag,
                    "coords": coords
                }
            })
            # print(link)
            # print(title)
        # print(rooms)
    save_json(rooms, args.save_path)
    

if __name__ == "__main__":
    args = parser.parse_args()
    soups = read_html_data(args.input)
    rooms = extract_rooms(soups)



