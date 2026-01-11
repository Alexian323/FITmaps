"""
Test script for find_shortest_path.py
Tests various pathfinding scenarios
"""

import sys
from find_shortest_path import shortest_path, load_edges

def test_path(start, end, description):
    """Test a single path and print results."""
    print(f"\n{'='*60}")
    print(f"Test: {description}")
    print(f"From: {start}")
    print(f"To: {end}")
    print(f"{'='*60}")
    
    # Load graph to check if nodes exist
    graph = load_edges("edges.csv")
    
    if start not in graph:
        print(f"❌ ERROR: Start node '{start}' not found in graph")
        return False
    
    if end not in graph:
        print(f"❌ ERROR: End node '{end}' not found in graph")
        return False
    
    # Find shortest path
    edges, total_distance = shortest_path(start, end)
    
    if edges is None:
        print(f"❌ No path found from {start} to {end}")
        return False
    
    print(f"\n✅ Path found!")
    print(f"\nPath ({len(edges)} steps):")
    print("-" * 60)
    
    for i, edge in enumerate(edges, 1):
        print(f"{i:2d}. {edge['room1']:15s} -> {edge['room2']:15s}  (dist: {edge['dist']:.6f})")
    
    print("-" * 60)
    print(f"\nTotal distance (graph units): {total_distance:.6f}")
    print(f"Total distance (estimated meters): {total_distance * 20000:.2f}")
    print(f"Number of steps: {len(edges)}")
    
    return True

def main():
    """Run multiple test cases."""
    print("="*60)
    print("SHORTEST PATH TESTING")
    print("="*60)
    
    # Test cases
    test_cases = [
        # Same floor - nearby rooms
        ("A109__+1", "A103__+1", "Same floor: A109 to A103 (adjacent)"),
        ("A103__+1", "A104__+1", "Same floor: A103 to A104 (adjacent corridors)"),
        ("A101__+1", "A109__+1", "Same floor: A101 to A109 (through corridors)"),
        
        # Same floor - longer paths
        ("A101__+1", "A121__+1", "Same floor: A101 to A121 (longer path)"),
        ("A109__+1", "A114__+1", "Same floor: A109 to A114 (multiple steps)"),
        
        # Cross-floor navigation
        ("A108__+1", "A000__-1", "Cross-floor: Floor +1 to Floor -1 (via staircase)"),
        ("A108__+1", "A214__+2", "Cross-floor: Floor +1 to Floor +2 (via staircase)"),
        
        # Different areas
        ("A101__+1", "A214__+2", "Multi-floor: A101 to A214 (cross multiple floors)"),
    ]
    
    passed = 0
    failed = 0
    
    for start, end, description in test_cases:
        if test_path(start, end, description):
            passed += 1
        else:
            failed += 1
    
    # Summary
    print(f"\n{'='*60}")
    print("TEST SUMMARY")
    print(f"{'='*60}")
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    print(f"Total: {passed + failed}")
    print(f"{'='*60}\n")
    
    # Show some statistics about the graph
    graph = load_edges("edges.csv")
    print(f"Graph Statistics:")
    print(f"  Total nodes: {len(graph)}")
    
    # Count connections
    total_edges = sum(len(neighbors) for neighbors in graph.values()) // 2
    print(f"  Total edges: {total_edges}")
    
    # Find nodes with most connections
    node_degrees = [(node, len(neighbors)) for node, neighbors in graph.items()]
    node_degrees.sort(key=lambda x: x[1], reverse=True)
    print(f"\n  Most connected nodes:")
    for node, degree in node_degrees[:5]:
        print(f"    {node}: {degree} connections")

if __name__ == "__main__":
    main()





