#!/usr/bin/python

import sys
import json
import random

if (sys.version_info > (3, 0)):
    print("Python 3.X detected")
    import socketserver as ss
else:
    print("Python 2.X detected")
    import SocketServer as ss


class NetworkHandler(ss.StreamRequestHandler):
    def handle(self):
        game = Game()

        while True:
            data = self.rfile.readline().decode()  # reads until '\n' encountered
            json_data = json.loads(str(data))
            response = game.process_updates(json_data).encode()
            self.wfile.write(response)


class Unit:
    def __init__(self, unit_data):
        self.id = unit_data['id']
        self.player_id = unit_data['player_id']
        self.x = unit_data['x']
        self.y = unit_data['y']
        self.type = unit_data['type']
        self.status = unit_data['status']
        self.health = unit_data['health']
        self.resource = unit_data.get('resource', 0)

    def update(self, unit_data):
        self.x = unit_data['x']
        self.y = unit_data['y']
        self.status = unit_data['status']
        self.health = unit_data['health']
        self.resource = unit_data.get('resource', self.resource)

    def is_idle(self):
        return self.status == 'idle'


class Tile:
    def __init__(self, tile_data):
        self.x = tile_data['x']
        self.y = tile_data['y']
        self.visible = tile_data.get('visible', False)
        self.blocked = tile_data.get('blocked', False)
        self.resources = tile_data.get('resources', None)
        self.units = tile_data.get('units', [])
        if self.resources:
            print(f"New tile created at ({self.x}, {self.y}) with resources: {self.resources}")

    def update(self, tile_data):
        self.visible = tile_data.get('visible', self.visible)
        self.blocked = tile_data.get('blocked', self.blocked)
        self.resources = tile_data.get('resources', self.resources)
        self.units = tile_data.get('units', self.units)
        if self.resources:
            print(f"Tile at ({self.x}, {self.y}) updated with resources: {self.resources}")


class World:
    def __init__(self):
        self.units_by_id = {}
        self.tiles = {}

    def update_units(self, unit_updates):
        for unit_data in unit_updates:
            unit_id = unit_data['id']
            if unit_id in self.units_by_id:
                self.units_by_id[unit_id].update(unit_data)
            else:
                self.units_by_id[unit_id] = Unit(unit_data)

    def update_tiles(self, tile_updates):
        for tile_data in tile_updates:
            tile_key = (tile_data['x'], tile_data['y'])
            if tile_key in self.tiles:
                self.tiles[tile_key].update(tile_data)
            else:
                self.tiles[tile_key] = Tile(tile_data)
            if self.tiles[tile_key].resources:
                print(f"Updated tile at {tile_key} has resources: {self.tiles[tile_key].resources}")

    def get_tile(self, x, y):
        return self.tiles.get((x, y))

    def get_adjacent_resource_tile(self, unit):
        directions = [(0, -1), (0, 1), (-1, 0), (1, 0)]  # N, S, W, E
        for dx, dy in directions:
            tile = self.get_tile(unit.x + dx, unit.y + dy)
            if tile and tile.visible and tile.resources:
                print(f"Found adjacent resource at ({tile.x}, {tile.y})")
                return tile
        return None


class CommandBuilder:
    MOVE_COMMAND = 'MOVE'
    GATHER_COMMAND = 'GATHER'
    DROP_COMMAND = 'DROP'
    CREATE_COMMAND = 'CREATE'
    SHOOT_COMMAND = 'SHOOT'
    MELEE_COMMAND = 'MELEE'

    @staticmethod
    def move(unit, direction):
        return {"command": CommandBuilder.MOVE_COMMAND, "unit": unit.id, "dir": direction}

    @staticmethod
    def gather(unit, direction):
        print(f"Creating GATHER command for unit {unit.id} in direction {direction}")
        command = {"command": CommandBuilder.GATHER_COMMAND, "unit": unit.id, "dir": direction}
        print(f"Gather command created: {command}")
        return command

    @staticmethod
    def drop(unit, direction):
        return {"command": CommandBuilder.DROP_COMMAND, "unit": unit.id, "dir": direction}

    @staticmethod
    def create(unit_type):
        """Create a new unit at the base."""
        return {
            "command": CommandBuilder.CREATE_COMMAND,
            "type": unit_type
        }


class Game:
    def __init__(self):
        self.world = World()
        self.base_location = None
        self.resources = 0
        self.map_width = 0
        self.map_height = 0
        self.worker_count = 0
        self.scout_count = 0
        self.tank_count = 0
        self.player_id = None
        self.unit_costs = {
            'worker': 100,
            'scout': 130,
            'tank': 150
        }

    def find_nearest_resource(self, unit):
        """Find the nearest visible resource tile to the given unit."""
        nearest_resource = None
        min_distance = float('inf')
        
        for tile in self.world.tiles.values():
            if tile.visible and tile.resources:
                distance = self.manhattan_distance(unit.x, unit.y, tile.x, tile.y)
                if distance < min_distance:
                    min_distance = distance
                    nearest_resource = tile
                    print(f"Found closer resource at ({tile.x}, {tile.y}), distance: {distance}")
        
        return nearest_resource

    def is_tile_blocked(self, x, y):
        """Check if a tile is blocked."""
        tile = self.world.get_tile(x, y)
        return tile and tile.blocked

    def manhattan_distance(self, x1, y1, x2, y2):
        """Calculate Manhattan distance between two points."""
        return abs(x2 - x1) + abs(y2 - y1)

    def is_adjacent(self, unit, tile):
        """Check if a unit is adjacent to a tile."""
        dx = abs(unit.x - tile.x)
        dy = abs(unit.y - tile.y)
        # Debug print
        print(f"Checking adjacency: unit({unit.x},{unit.y}) to tile({tile.x},{tile.y})")
        print(f"dx={dx}, dy={dy}")
        # Must be exactly 1 tile away in either x OR y direction, not both
        return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)

    def is_in_range(self, unit, target):
        """Check if target is within unit's vision/attack range."""
        distance = self.manhattan_distance(unit.x, unit.y, target.x, target.y)
        vision_ranges = {
            'worker': 2,
            'scout': 5,
            'tank': 2
        }
        return distance <= vision_ranges.get(unit.type, 2)

    def get_direction_to_tile(self, unit, tile):
        """Get the direction to move towards a tile."""
        dx = tile.x - unit.x
        dy = tile.y - unit.y
        
        # Consider both x and y differences to choose the best direction
        # Move in the direction of the larger difference first
        if abs(dx) > abs(dy):
            return 'E' if dx > 0 else 'W'
        elif abs(dy) > abs(dx):
            return 'S' if dy > 0 else 'N'
        else:
            # If differences are equal, choose randomly between the two options
            return random.choice(['E' if dx > 0 else 'W', 'S' if dy > 0 else 'N'])

    def get_direction_to_coordinates(self, unit, target_x, target_y):
        """Get the direction to move towards specific coordinates."""
        dx = target_x - unit.x
        dy = target_y - unit.y
        
        print(f"Getting direction from ({unit.x}, {unit.y}) to ({target_x}, {target_y})")
        print(f"dx={dx}, dy={dy}")
        
        # Must move in cardinal directions
        if abs(dx) > abs(dy):
            direction = 'E' if dx > 0 else 'W'
        else:
            direction = 'S' if dy > 0 else 'N'
        
        print(f"Chose direction: {direction}")
        return direction

    def can_afford(self, unit_type):
        """Check if we can afford to create a unit while maintaining resource buffer."""
        if unit_type is None:
            return False
        
        cost = self.unit_costs.get(unit_type)
        if cost is None:
            return False
        
        # Higher resource buffers to maintain larger resource pool
        buffer = {
            'worker': 100,  # Increased worker buffer
            'scout': 150,   # Increased scout buffer
        }.get(unit_type, 150)
        
        can_afford = self.resources >= (cost + buffer)
        print(f"Checking if can afford {unit_type} (cost: {cost}, resources: {self.resources}, buffer: {buffer}): {can_afford}")
        return can_afford

    def find_nearest_enemy(self, unit):
        """Find the nearest visible enemy unit."""
        nearest_enemy = None
        min_distance = float('inf')
        
        for x in range(self.map_width):
            for y in range(self.map_height):
                tile = self.world.get_tile(x, y)
                if tile and tile.visible and tile.units:
                    for enemy_data in tile.units:
                        # Only consider units from other players
                        if enemy_data['player_id'] != self.player_id:
                            # Add tile coordinates to enemy data
                            enemy_data = enemy_data.copy()  # Create a copy to avoid modifying original
                            enemy_data['x'] = tile.x
                            enemy_data['y'] = tile.y
                            # Create a Unit object from the enhanced enemy data
                            enemy = Unit(enemy_data)
                            distance = self.manhattan_distance(unit.x, unit.y, x, y)
                            if distance < min_distance:
                                min_distance = distance
                                nearest_enemy = enemy
        
        return nearest_enemy

    def find_nearest_worker(self, unit):
        """Find the nearest friendly worker unit."""
        nearest_worker = None
        min_distance = float('inf')
        
        for other_unit in self.world.units_by_id.values():
            if other_unit.type == 'worker' and other_unit.id != unit.id:
                distance = self.manhattan_distance(unit.x, unit.y, 
                                                other_unit.x, other_unit.y)
                if distance < min_distance:
                    min_distance = distance
                    nearest_worker = other_unit
        
        return nearest_worker

    def process_updates(self, json_data):
        # Print full game info at start
        if 'game_info' in json_data:
            print("\n=== GAME INITIALIZATION ===")
            print(f"Map size: {json_data['game_info']['map_width']}x{json_data['game_info']['map_height']}")
            print(f"Game duration: {json_data['game_info']['game_duration']}ms")
            print(f"Turn duration: {json_data['game_info']['turn_duration']}ms")
            
            print("\nStarting Resources:")
            if 'resources' in json_data:
                self.resources = json_data['resources']  # Set initial resources
                print(f"  Current: {self.resources}")
            
            print("\nUnit Information:")
            for unit_type, info in json_data['game_info']['unit_info'].items():
                print(f"\n{unit_type.upper()}:")
                for stat, value in info.items():
                    print(f"  {stat}: {value}")
            
            print("\nStarting Units:")
            print(f"  Workers: 6")  # Server starts with 6 workers (STARTING_WORKERS constant)
            print(f"  Base: 1")
            
            print("\n=========================\n")

            self.map_width = json_data['game_info']['map_width']
            self.map_height = json_data['game_info']['map_height']
            self.unit_costs = {unit_type: info['cost'] 
                              for unit_type, info in json_data['game_info']['unit_info'].items()
                              if 'cost' in info}
            print(f"Game info received - map size: {self.map_width}x{self.map_height}")

        # Update resources from game state
        if 'resources' in json_data:
            old_resources = self.resources
            self.resources = json_data['resources']
            print(f"Resources updated: {old_resources} -> {self.resources}")

        # Store player_id when received
        if 'player_id' in json_data:
            self.player_id = json_data['player_id']
            print(f"Player ID: {self.player_id}")

        # Add debug logging
        print(f"Received update: {json_data.keys()}")
        
        # Update world state
        if 'tile_updates' in json_data:
            print(f"Updating {len(json_data['tile_updates'])} tiles")
            self.world.update_tiles(json_data['tile_updates'])
            
        if 'unit_updates' in json_data:
            # Reset unit counts before updating
            self.worker_count = 0
            self.scout_count = 0
            self.tank_count = 0
            
            print(f"Updating {len(json_data['unit_updates'])} units")
            self.world.update_units(json_data['unit_updates'])
            
            # Update unit counts and track base resources
            for unit_data in json_data['unit_updates']:
                if unit_data['type'] == 'base':
                    self.base_location = (unit_data['x'], unit_data['y'])
                    if 'resource' in unit_data:  # Track base's resources
                        self.resources = unit_data['resource']
                    print(f"Base located at {self.base_location} with resources: {self.resources}")
                elif unit_data['type'] == 'worker':
                    self.worker_count += 1
                elif unit_data['type'] == 'scout':
                    self.scout_count += 1
                elif unit_data['type'] == 'tank':
                    self.tank_count += 1

        commands = self.get_commands()
        return json.dumps({"commands": commands}, separators=(',', ':')) + '\n'

    def get_commands(self):
        print(f"\nCurrent state:")
        print(f"- Resources: {self.resources}")
        print(f"- Base location: {self.base_location}")
        print(f"- Unit counts: W={self.worker_count}, S={self.scout_count}")
        
        commands = []
        idle_workers = []
        idle_scouts = []

        # Categorize idle units
        for unit in self.world.units_by_id.values():
            if unit.is_idle():
                if unit.type == 'worker':
                    idle_workers.append(unit)
                elif unit.type == 'scout':
                    idle_scouts.append(unit)

        # Worker logic
        for worker in idle_workers:
            print(f"\nProcessing worker {worker.id} at ({worker.x}, {worker.y}) with resource: {worker.resource}")
            
            if worker.resource > 0:
                # Return to base if carrying resources
                if self.base_location:
                    print(f"Worker {worker.id} has resources, returning to base at {self.base_location}")
                    direction = self.get_direction_to_coordinates(worker, self.base_location[0], self.base_location[1])
                    
                    # If adjacent to base, drop resources
                    if self.manhattan_distance(worker.x, worker.y, self.base_location[0], self.base_location[1]) == 1:
                        print(f"Worker {worker.id} dropping resources at base")
                        commands.append(CommandBuilder.drop(worker, direction))
                    else:
                        print(f"Worker {worker.id} moving to base in direction {direction}")
                        commands.append(CommandBuilder.move(worker, direction))
            else:
                # Check adjacent tiles for resources first
                adjacent_resource = self.world.get_adjacent_resource_tile(worker)
                if adjacent_resource:
                    direction = self.get_direction_to_tile(worker, adjacent_resource)
                    print(f"Worker {worker.id} gathering from adjacent resource at ({adjacent_resource.x}, {adjacent_resource.y})")
                    commands.append(CommandBuilder.gather(worker, direction))
                else:
                    # Find nearest visible resource
                    nearest_resource = self.find_nearest_resource(worker)
                    if nearest_resource:
                        direction = self.get_direction_to_coordinates(worker, nearest_resource.x, nearest_resource.y)
                        print(f"Worker {worker.id} moving to resource at ({nearest_resource.x}, {nearest_resource.y}) in direction {direction}")
                        commands.append(CommandBuilder.move(worker, direction))
                    else:
                        # No visible resources, explore
                        direction = self.get_strategic_exploration_direction(worker)
                        print(f"Worker {worker.id} exploring in direction {direction}")
                        commands.append(CommandBuilder.move(worker, direction))

        # Scout logic - prioritize exploration
        for scout in idle_scouts:
            direction = self.get_strategic_exploration_direction(scout)
            commands.append(CommandBuilder.move(scout, direction))

        # Unit creation logic
        if self.base_location:
            next_unit = self.determine_next_unit_to_create()
            if next_unit and self.can_afford(next_unit):
                print(f"Creating new {next_unit} unit")
                commands.append(CommandBuilder.create(next_unit))
            else:
                print(f"Cannot create {next_unit}: resources={self.resources}")

        return commands

    def determine_next_unit_to_create(self):
        """Determine which unit type should be created next based on game state."""
        # Don't create units if we're close to resource cap
        if self.resources >= 700:  # Keep resources if near cap
            return None

        # Count visible resources
        visible_resources = sum(1 for tile in self.world.tiles.values() 
                              if tile.visible and tile.resources)

        # Very conservative unit limits
        max_workers = 4  # Reduced worker cap
        max_scouts = 2   # Limited scouts for exploration

        # Don't create units if we're at capacity
        if self.worker_count >= max_workers and self.scout_count >= max_scouts:
            return None

        # Resource efficiency checks - higher buffer to accumulate more resources
        min_resource_buffer = 300  # Increased minimum resource buffer
        if self.resources < min_resource_buffer:
            return None

        # Early game - ensure minimum worker count
        if self.worker_count < 2:
            return 'worker'

        # Prioritize based on current needs
        if self.worker_count < max_workers and visible_resources > self.worker_count * 2:
            return 'worker'
        if self.scout_count < max_scouts and self.worker_count >= 2:
            return 'scout'

        return None

    def get_strategic_exploration_direction(self, unit):
        weights = {'N': 0, 'S': 0, 'E': 0, 'W': 0}
        
        # Define direction vectors
        directions = {
            'N': (0, -1), 'S': (0, 1), 'E': (1, 0), 'W': (-1, 0)
        }
        
        # Penalize blocked directions heavily
        for direction, (dx, dy) in directions.items():
            next_x, next_y = unit.x + dx, unit.y + dy
            if self.is_tile_blocked(next_x, next_y):
                weights[direction] -= 10
                continue
            
            # Look ahead for walls and obstacles
            for distance in range(1, 4):
                x, y = unit.x + dx * distance, unit.y + dy * distance
                if 0 <= x < self.map_width and 0 <= y < self.map_height:
                    tile = self.world.get_tile(x, y)
                    if not tile or not tile.visible:
                        weights[direction] += 3 - distance  # Closer unexplored tiles worth more
                    elif tile.blocked:
                        weights[direction] -= 2  # Penalize directions leading to walls
                    
                    # Add weight for resources (especially for workers)
                    if tile and tile.resources and unit.type == 'worker':
                        weights[direction] += 4 - distance
        
        # Encourage varied exploration for scouts
        if unit.type == 'scout':
            # Get the unit's previous positions from last 5 turns (you'll need to track this)
            recent_positions = self.get_unit_recent_positions(unit.id)
            if recent_positions:
                # Penalize directions that lead back to recent positions
                for direction, (dx, dy) in directions.items():
                    next_pos = (unit.x + dx, unit.y + dy)
                    if next_pos in recent_positions:
                        weights[direction] -= 3
        
        # Add randomness to prevent units from getting stuck
        for direction in weights:
            weights[direction] += random.uniform(0, 1)
        
        # Choose direction with highest weight, but if all directions are bad,
        # try to find an alternative route
        max_weight = max(weights.values())
        if max_weight < -5:  # All directions are heavily penalized
            return self.find_alternative_route(unit)
        
        best_directions = [d for d, w in weights.items() if w == max_weight]
        return random.choice(best_directions)

    def find_alternative_route(self, unit):
        """Find an alternative route when stuck."""
        # Try diagonal movements (combining two directions)
        diagonal_moves = [
            ('N', 'E'), ('N', 'W'), ('S', 'E'), ('S', 'W')
        ]
        
        for d1, d2 in diagonal_moves:
            dx1, dy1 = {'N': (0, -1), 'S': (0, 1), 'E': (1, 0), 'W': (-1, 0)}[d1]
            dx2, dy2 = {'N': (0, -1), 'S': (0, 1), 'E': (1, 0), 'W': (-1, 0)}[d2]
            
            # Check both possible paths to the diagonal
            path1 = [(unit.x + dx1, unit.y), (unit.x + dx1 + dx2, unit.y + dy2)]
            path2 = [(unit.x, unit.y + dy2), (unit.x + dx1, unit.y + dy2)]
            
            for path in [path1, path2]:
                if all(not self.is_tile_blocked(x, y) for x, y in path):
                    return d1 if path == path1 else d2
        
        # If still stuck, return a random unblocked direction
        valid_directions = []
        for direction, (dx, dy) in {'N': (0, -1), 'S': (0, 1), 'E': (1, 0), 'W': (-1, 0)}.items():
            if not self.is_tile_blocked(unit.x + dx, unit.y + dy):
                valid_directions.append(direction)
        
        return random.choice(valid_directions) if valid_directions else 'N'

    def get_unit_recent_positions(self, unit_id):
        """Track recent positions of units to prevent getting stuck in loops."""
        if not hasattr(self, '_unit_positions'):
            self._unit_positions = {}
        
        if unit_id not in self._unit_positions:
            self._unit_positions[unit_id] = []
        
        positions = self._unit_positions[unit_id]
        unit = self.world.units_by_id.get(unit_id)
        if unit:
            positions.append((unit.x, unit.y))
            # Keep only last 5 positions
            self._unit_positions[unit_id] = positions[-5:]
        
        return self._unit_positions.get(unit_id, [])

    def is_unit_stuck(self, unit):
        """Check if a unit has been in the same position for multiple turns."""
        if not hasattr(self, '_unit_position_history'):
            self._unit_position_history = {}
        
        unit_id = unit.id
        current_pos = (unit.x, unit.y)
        
        if unit_id not in self._unit_position_history:
            self._unit_position_history[unit_id] = []
        
        history = self._unit_position_history[unit_id]
        history.append(current_pos)
        history = history[-5:]  # Keep last 5 positions
        self._unit_position_history[unit_id] = history
        
        # Unit is stuck if it's been in the same position for 3+ turns
        return len(history) >= 3 and all(pos == current_pos for pos in history[-3:])

    def get_unstuck_direction(self, unit, target_tile):
        """Find an alternative path when a unit is stuck."""
        current_pos = (unit.x, unit.y)
        target_pos = (target_tile.x, target_tile.y)
        
        # Try all possible directions
        directions = ['N', 'S', 'E', 'W']
        valid_moves = []
        
        for direction in directions:
            dx, dy = {
                'N': (0, -1),
                'S': (0, 1),
                'E': (1, 0),
                'W': (-1, 0)
            }[direction]
            
            new_x, new_y = unit.x + dx, unit.y + dy
            
            # Check if move is valid
            if self.is_valid_move(new_x, new_y):
                # Calculate how good this move is
                score = self.evaluate_move(
                    current_pos, 
                    (new_x, new_y), 
                    target_pos,
                    self._unit_position_history.get(unit.id, [])
                )
                valid_moves.append((direction, score))
        
        if valid_moves:
            # Choose the direction with the highest score
            return max(valid_moves, key=lambda x: x[1])[0]
        
        # If no valid moves, return random direction as last resort
        return random.choice(directions)

    def is_valid_move(self, x, y):
        """Check if a move to the given coordinates is valid."""
        # Check map boundaries
        if x < 0 or x >= self.map_width or y < 0 or y >= self.map_height:
            return False
        
        # Check if tile is blocked
        tile = self.world.get_tile(x, y)
        if tile and tile.blocked:
            return False
        
        return True

    def evaluate_move(self, current_pos, new_pos, target_pos, position_history):
        """Score a potential move based on various factors."""
        score = 0
        
        # Prefer moves that get closer to target
        current_distance = self.manhattan_distance(current_pos[0], current_pos[1], 
                                                target_pos[0], target_pos[1])
        new_distance = self.manhattan_distance(new_pos[0], new_pos[1], 
                                             target_pos[0], target_pos[1])
        score += (current_distance - new_distance) * 10
        
        # Heavily penalize moving to a recently visited position
        if new_pos in position_history[-4:]:  # Check last 4 positions
            score -= 20
        
        # Penalize moving back and forth
        if len(position_history) >= 2 and new_pos == position_history[-2]:
            score -= 15
        
        # Add small random factor to break ties
        score += random.uniform(0, 1)
        
        return score

    def find_path(self, unit, target_x, target_y):
        """A* pathfinding implementation."""
        from heapq import heappush, heappop
        
        def heuristic(x, y):
            return abs(x - target_x) + abs(y - target_y)
        
        start = (unit.x, unit.y)
        goal = (target_x, target_y)
        
        # Priority queue of positions to check
        frontier = []
        heappush(frontier, (0, start))
        
        # Keep track of where we came from
        came_from = {start: None}
        
        # Cost so far to reach each position
        cost_so_far = {start: 0}
        
        while frontier:
            current = heappop(frontier)[1]
            
            if current == goal:
                break
                
            # Check all adjacent tiles
            for dx, dy in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
                next_pos = (current[0] + dx, current[1] + dy)
                
                # Skip if out of bounds
                if not (0 <= next_pos[0] < self.map_width and 0 <= next_pos[1] < self.map_height):
                    continue
                    
                # Skip if blocked
                tile = self.world.get_tile(next_pos[0], next_pos[1])
                if tile and tile.blocked:
                    continue
                
                # Calculate new cost
                new_cost = cost_so_far[current] + 1
                
                # If we haven't been here before, or found a better path
                if next_pos not in cost_so_far or new_cost < cost_so_far[next_pos]:
                    cost_so_far[next_pos] = new_cost
                    priority = new_cost + heuristic(next_pos[0], next_pos[1])
                    heappush(frontier, (priority, next_pos))
                    came_from[next_pos] = current
        
        # Reconstruct path
        if goal not in came_from:
            return None
                
        path = []
        current = goal
        while current is not None:
            path.append(current)
            current = came_from[current]
        path.reverse()
        
        return path


if __name__ == "__main__":
    port = int(sys.argv[1]) if (len(sys.argv) > 1 and sys.argv[1]) else 9090
    host = '0.0.0.0'

    server = ss.TCPServer((host, port), NetworkHandler)
    print("listening on {}:{}".format(host, port))
    server.serve_forever()