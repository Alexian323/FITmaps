import json
import csv
from math import sqrt

INPUT_JSON = "maps_data_full_with_floor_no_with_gps_coords.json"
OUTPUT_NODES = "nodes.csv"
OUTPUT_EDGES = "edges.csv"

EPS = 1e-9                        # boundary tolerance
BIDIR = True                   # edges are bidirectional
VERTICAL_DISTANCE = 5.4e-5      # 6 meters in GPS degrees

# -------------------------------------------------------
# Geometry helpers
# -------------------------------------------------------

def point_to_segment_distance(px, py, x1, y1, x2, y2):
    dx = x2 - x1
    dy = y2 - y1
    if dx == 0 and dy == 0:
        return sqrt((px - x1)**2 + (py - y1)**2)
    t = ((px - x1)*dx + (py - y1)*dy) / (dx*dx + dy*dy)
    t = max(0.0, min(1.0, t))
    cx = x1 + t*dx
    cy = y1 + t*dy
    return sqrt((px - cx)**2 + (py - cy)**2)


def on_polygon_boundary(px, py, pts, eps):
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i+1) % len(pts)]
        if point_to_segment_distance(px, py, x1, y1, x2, y2) <= eps:
            return True
    return False


def point_in_polygon(px, py, pts):
    inside = False
    n = len(pts)
    if n < 3:
        return False
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        intersect = ((yi > py) != (yj > py)) and \
                    (px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi)
        if intersect:
            inside = not inside
        j = i
    return inside


def door_touch_type(door, room):
    (mx, my) = door["mid"]
    if on_polygon_boundary(mx, my, room["pts"], EPS):
        return "boundary"
    if point_in_polygon(mx, my, room["pts"]):
        return "inside"
    return "none"


def centroid(pts):
    if not pts:
        return (0,0)
    sx = sum(p[0] for p in pts)
    sy = sum(p[1] for p in pts)
    return (sx / len(pts), sy / len(pts))


def polygon_area(pts):
    area = 0
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i+1) % len(pts)]
        area += x1*y2 - x2*y1
    return abs(area) / 2


def polygon_clip(subject, clip):
    if not subject or not clip:
        return []

    def inside(p, cp1, cp2):
        return (cp2[0]-cp1[0])*(p[1]-cp1[1]) >= (cp2[1]-cp1[1])*(p[0]-cp1[0])

    def intersection(s, p, cp1, cp2):
        dc = (cp1[0]-cp2[0], cp1[1]-cp2[1])
        dp = (s[0]-p[0], s[1]-p[1])
        n1 = cp1[0]*cp2[1] - cp1[1]*cp2[0]
        n2 = s[0]*p[1] - s[1]*p[0]
        denom = dc[0]*dp[1] - dc[1]*dp[0]
        if denom == 0:
            return p
        x = (n1*dp[0] - dc[0]*n2) / denom
        y = (n1*dp[1] - dc[1]*n2) / denom
        return (x,y)

    output = subject[:]
    cp1 = clip[-1]

    for cp2 in clip:
        input_list = output
        if not input_list:
            return []
        output = []
        s = input_list[-1]
        for p in input_list:
            if inside(p, cp1, cp2):
                if not inside(s, cp1, cp2):
                    output.append(intersection(s,p,cp1,cp2))
                output.append(p)
            elif inside(s, cp1, cp2):
                output.append(intersection(s,p,cp1,cp2))
            s = p
        cp1 = cp2
    return output


def polygons_adjacent(poly1, poly2, threshold_ratio=0.01):
    if not poly1 or not poly2 or len(poly1) < 3 or len(poly2) < 3:
        return False
    
    area1 = polygon_area(poly1)
    area2 = polygon_area(poly2)
    
    if area1 == 0 or area2 == 0:
        return False
    
    # Check for overlap using polygon clipping
    inter = polygon_clip(poly1, poly2)
    if inter:
        inter_area = polygon_area(inter)
        # Consider adjacent if there's any overlap (they share space)
        # or if intersection area is significant relative to smaller polygon
        min_area = min(area1, area2)
        if inter_area >= min_area * threshold_ratio:
            return True
    
    # Check if any vertex of one polygon is on or near the boundary of the other
    # Use a larger tolerance for boundary detection (GPS coordinates are small)
    boundary_tolerance = EPS * 1000  # Larger tolerance for GPS coordinates
    for pt in poly1:
        if on_polygon_boundary(pt[0], pt[1], poly2, boundary_tolerance):
            return True
    
    for pt in poly2:
        if on_polygon_boundary(pt[0], pt[1], poly1, boundary_tolerance):
            return True
    
    return False


# -------------------------------------------------------
# Load JSON
# -------------------------------------------------------

with open(INPUT_JSON, "r", encoding="utf-8") as f:
    data = json.load(f)

floors = {
    "-2": {"nodes": [], "doors": []},
    "-1": {"nodes": [], "doors": []},
    "1": {"nodes": [], "doors": []},
    "2": {"nodes": [], "doors": []},
    "3": {"nodes": [], "doors": []},
    "extra": {"nodes": [], "doors": []},
}

# -------------------------------------------------------
# Parse JSON → nodes + doors
# -------------------------------------------------------

for entry in data:
    object_id = list(entry.keys())[0]
    info = entry[object_id]

    raw_title = info.get("title", "").strip()
    title = raw_title.split("\n")[0].strip().lower()

    floor_raw = info.get("floor_no", "").strip()
    floor = floor_raw.replace("+", "")

    if floor not in floors:
        continue

    pts = info.get("gps_coords", [])

    if "elevator" in title:
        t = "elevator"
    elif "staircase" in title:
        t = "staircase"
    elif "extra_area" in title or object_id.startswith("extra_"):
        t = "corridor"  # Mark extra areas as corridors
    else:
        t = "normal"

    if title == "door":
        if len(pts) >= 2:
            (x1,y1) = pts[0]
            (x2,y2) = pts[1]
            mx = (x1+x2)/2
            my = (y1+y2)/2
            floors[floor]["doors"].append({
                "mid": (mx,my),
                "seg": [(x1,y1),(x2,y2)],
                "id": object_id
            })
        continue

    floors[floor]["nodes"].append({
        "id": object_id,
        "name": raw_title.split("\n")[0],
        "floor": floor,
        "pts": pts,
        "centroid": centroid(pts),
        "type": t
    })


# -------------------------------------------------------
# EXPORT NODES CSV
# -------------------------------------------------------

with open(OUTPUT_NODES, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["id", "name", "floor"])

    for fl, group in floors.items():
        for n in group["nodes"]:
            w.writerow([n["id"], n["name"], n["floor"]])



# -------------------------------------------------------
# BUILD EDGES (horizontal)
# -------------------------------------------------------

edges = set()

for floor, group in floors.items():
    nodes = group["nodes"]
    doors = group["doors"]

    for door in doors:
        touched = []
        for n in nodes:
            t = door_touch_type(door, n)
            if t != "none":
                touched.append((n, t))

        for i in range(len(touched)):
            for j in range(i+1, len(touched)):
                nA, typeA = touched[i]
                nB, typeB = touched[j]
                edges.add((nA["id"], nB["id"], floor))
                if BIDIR:
                    edges.add((nB["id"], nA["id"], floor))


# -------------------------------------------------------
# BUILD EDGES (corridors and adjacent rooms)
# Connect corridors (extra areas) to each other and to adjacent rooms
# -------------------------------------------------------

for floor, group in floors.items():
    nodes = group["nodes"]
    
    corridors = [n for n in nodes if n["type"] == "corridor"]
    regular_rooms = [n for n in nodes if n["type"] == "normal"]
    
    for i in range(len(corridors)):
        for j in range(i+1, len(corridors)):
            corrA = corridors[i]
            corrB = corridors[j]
            
            if not corrA["pts"] or not corrB["pts"]:
                continue
            
            if polygons_adjacent(corrA["pts"], corrB["pts"]):
                edges.add((corrA["id"], corrB["id"], floor))
                if BIDIR:
                    edges.add((corrB["id"], corrA["id"], floor))
    
    for corridor in corridors:
        if not corridor["pts"]:
            continue
        
        for room in regular_rooms:
            if not room["pts"]:
                continue
            
            if polygons_adjacent(room["pts"], corridor["pts"]):
                edges.add((room["id"], corridor["id"], floor))
                if BIDIR:
                    edges.add((corridor["id"], room["id"], floor))


# -------------------------------------------------------
# BUILD EDGES (vertical)
# -------------------------------------------------------

floor_order = ["-2", "-1", "1", "2", "3"]

for i in range(len(floor_order)-1):

    floorA = floor_order[i]
    floorB = floor_order[i+1]

    nodesA = floors[floorA]["nodes"]
    nodesB = floors[floorB]["nodes"]

    for nA in nodesA:
        if nA["type"] not in ("elevator", "staircase"):
            continue

        for nB in nodesB:
            if nB["type"] != nA["type"]:
                continue

            if not nA["pts"] or not nB["pts"]:
                continue

            inter = polygon_clip(nA["pts"], nB["pts"])
            inter_area = polygon_area(inter)
            max_area = max(polygon_area(nA["pts"]), polygon_area(nB["pts"]))

            if inter_area >= max_area / 10:      # threshold = 1/10
                edges.add((nA["id"], nB["id"], "vertical"))
                if BIDIR:
                    edges.add((nB["id"], nA["id"], "vertical"))


# -------------------------------------------------------
# EXPORT EDGES CSV
# -------------------------------------------------------

with open(OUTPUT_EDGES, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["room1", "dist", "room2"])

    for (u, v, fl) in sorted(edges):
        if fl == "vertical":
            dist = VERTICAL_DISTANCE
        else:
            nu = next(n for n in floors[fl]["nodes"] if n["id"] == u)
            nv = next(n for n in floors[fl]["nodes"] if n["id"] == v)
            x1, y1 = nu["centroid"]
            x2, y2 = nv["centroid"]
            dist = round(sqrt((x1-x2)**2 + (y1-y2)**2), 6)

        w.writerow([u, dist, v])



print(f"✅ nodes.csv created: {OUTPUT_NODES}")
print(f"✅ edges.csv created: {OUTPUT_EDGES}")
