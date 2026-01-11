import csv
import heapq

def load_edges(path="edges.csv"):
    graph = {}
    with open(path, newline='', encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            r1 = row["room1"]
            r2 = row["room2"]
            dist = float(row["dist"])

            if r1 not in graph:
                graph[r1] = []
            if r2 not in graph:
                graph[r2] = []

            graph[r1].append((r2, dist))
            graph[r2].append((r1, dist))

    return graph


def dijkstra(graph, start, goal):
    pq = [(0, start)]
    visited = set()

    dist = {node: float("inf") for node in graph}
    dist[start] = 0
    prev = {node: None for node in graph}

    while pq:
        current_dist, node = heapq.heappop(pq)

        if node in visited:
            continue
        visited.add(node)

        if node == goal:
            break

        for neighbor, weight in graph[node]:
            new_d = current_dist + weight
            if new_d < dist[neighbor]:
                dist[neighbor] = new_d
                prev[neighbor] = node
                heapq.heappush(pq, (new_d, neighbor))

    return dist, prev


def reconstruct_path(prev, start, goal):
    path = []
    node = goal

    while node is not None:
        path.append(node)
        node = prev[node]

    path.reverse()
    if path[0] != start:
        return None
    return path


def get_edges_from_path(path, graph):
    edges_taken = []
    weight_lookup = {}
    for node in graph:
        for neigh, w in graph[node]:
            weight_lookup[(node, neigh)] = w

    for i in range(len(path) - 1):
        r1 = path[i]
        r2 = path[i + 1]
        dist = weight_lookup[(r1, r2)]
        edges_taken.append({
            "room1": r1,
            "dist": dist,
            "room2": r2
        })

    return edges_taken


def shortest_path(start, goal, edges_file="edges.csv"):
    graph = load_edges(edges_file)
    dist, prev = dijkstra(graph, start, goal)
    path = reconstruct_path(prev, start, goal)

    if path is None:
        return None, None

    edges = get_edges_from_path(path, graph)
    total_distance = dist[goal]

    return edges, total_distance


if __name__ == "__main__":
    graph = load_edges("edges.csv")

    start_node = input("Enter start node ID: ").strip()
    end_node = input("Enter end node ID: ").strip()
    if (start_node not in graph) or (end_node not in graph):
        print(f"Error: It is not a valid room name.")
        quit()

    edges, total = shortest_path(start_node, end_node)

    if edges is None:
        print("No path found.")
    else:
        print("Edges taken:")
        for e in edges:
            print(e["room1"], e["dist"], e["room2"])

        print("Total distance (in GoogleMaps units):", total)
        print("Total distance (in meters):", total*20000)
