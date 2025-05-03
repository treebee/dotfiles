#!/usr/bin/python3

import argparse
import json
import os
import sys
import time
import uuid
from pathlib import Path

STATE_FILE = Path(os.path.expanduser("~/.todos-current.json"))
DB_FILE = Path(os.path.expanduser("~/.todos.jsonl"))


def read_database(db_path: Path) -> list[dict]:
    """Reads the newline-delimited JSON database file."""
    if not db_path.exists():
        return []
    todos = []
    try:
        with open(db_path, "r") as f:
            for line in f:
                try:
                    if line.strip():
                        todos.append(json.loads(line))
                except json.JSONDecodeError:
                    print(
                        f"Warning: Skipping invalid JSON line in {db_path}: {line.strip()}",
                        file=sys.stderr,
                    )
    except IOError as e:
        print(f"Error reading database file {db_path}: {e}", file=sys.stderr)
        return []  # Return empty list on error
    return todos


def write_database(db_path: Path, todos: list[dict]):
    """Writes the list of todos to the newline-delimited JSON database file."""
    try:
        with open(db_path, "w") as f:
            for todo in todos:
                json.dump(todo, f)
                f.write("\n")  # Corrected newline character
    except IOError as e:
        print(f"Error writing database file {db_path}: {e}", file=sys.stderr)


def read_state(state_path: Path) -> dict | None:
    """Reads the JSON state file."""
    if not state_path.exists():
        return None
    try:
        with open(state_path, "r") as f:
            content = f.read().strip()
            if not content:
                return None
            return json.loads(content)
    except (IOError, json.JSONDecodeError) as e:
        print(f"Error reading state file {state_path}: {e}", file=sys.stderr)
        return None


def write_state(state_path: Path, todo: dict | None):
    """Writes a todo dictionary (or empty object) to the state JSON file."""
    try:
        with open(state_path, "w") as f:
            if todo:
                json.dump(todo, f, indent=2)  # Use indent for readability
            else:
                # Write an empty JSON object or clear the file if no todo
                # Depending on Waybar's expectation, an empty object might be better
                # json.dump({}, f)
                pass  # Or simply leave the file empty/truncate it
    except IOError as e:
        print(f"Error writing state file {state_path}: {e}", file=sys.stderr)


def get_next_todo(todos: list[dict], current_id: str | None) -> dict | None:
    """Finds the next todo in the list, cycling if necessary."""
    if not todos:
        return None
    if current_id is None:
        return todos[0]

    try:
        current_index = next(
            i for i, todo in enumerate(todos) if todo.get("id") == current_id
        )
        next_index = (current_index + 1) % len(todos)
        return todos[next_index]
    except StopIteration:
        # Current ID not found in the list, return the first one
        return todos[0]


def handle_add(args):
    todos = read_database(DB_FILE)
    new_id = str(uuid.uuid4())
    new_todo = {"todo": args.todo, "id": new_id}
    todos.append(new_todo)
    write_database(DB_FILE, todos)
    print(f"Added todo: '{args.todo}' with id {new_id}")

    # If this is the first todo, update the state file
    current_state = read_state(STATE_FILE)
    if current_state is None and len(todos) == 1:
        write_state(STATE_FILE, new_todo)
        print(f"Set '{new_todo['todo']}' as current.")


def handle_remove(args):
    current_state = read_state(STATE_FILE)
    if not current_state or "id" not in current_state:
        print("No current todo set in state file to remove.", file=sys.stderr)
        return

    current_id = current_state["id"]
    todos = read_database(DB_FILE)
    initial_length = len(todos)
    todos_after_removal = [t for t in todos if t.get("id") != current_id]

    if len(todos_after_removal) == initial_length:
        print(f"Todo with id {current_id} not found in database.", file=sys.stderr)
        # Decide if we should still pick a new todo or clear the state
        # Let's clear the state if the ID wasn't even in the DB
        write_state(STATE_FILE, None)
        print("Cleared state file.", file=sys.stderr)

    else:
        write_database(DB_FILE, todos_after_removal)
        print(f"Removed todo with id {current_id}.")
        # Select the first remaining todo as the new current state
        new_current_todo = todos_after_removal[0] if todos_after_removal else None
        write_state(STATE_FILE, new_current_todo)
        if new_current_todo:
            print(f"Set '{new_current_todo['todo']}' as current.", file=sys.stderr)
        else:
            print("Database is now empty. Cleared state file.", file=sys.stderr)


def handle_toggle(args):
    current_state = read_state(STATE_FILE)
    todos = read_database(DB_FILE)

    if not todos:
        print("Database is empty. Cannot toggle.", file=sys.stderr)
        # Ensure state is also empty/cleared
        if current_state is not None:
            write_state(STATE_FILE, None)
        return

    current_id = current_state.get("id") if current_state else None
    next_todo = get_next_todo(todos, current_id)

    if next_todo:
        write_state(STATE_FILE, next_todo)
        print(f"Toggled to: '{next_todo['todo']}'", file=sys.stderr)
    elif current_state is not None:
        # This case might happen if DB has items but state points to non-existent ID
        # and get_next_todo correctly returned None (though current impl returns first)
        # Or if the database became empty between reading state and db.
        print("Could not determine next todo. Clearing state.", file=sys.stderr)
        write_state(STATE_FILE, None)


def _current_to_data(todo):
    data = json.loads(todo)
    data["text"] = data.pop("todo")
    return json.dumps(data)


def monitor_state_file(state_path: Path):
    """Monitors the state file for changes and prints its content."""
    last_mtime = None
    last_content = None

    # Initial print
    try:
        current_content = state_path.read_text()
        print(_current_to_data(current_content), flush=True)
        last_mtime = state_path.stat().st_mtime
        last_content = current_content
    except FileNotFoundError:
        print(
            "{}", flush=True
        )  # Print empty JSON object if file doesn't exist initially
        last_mtime = -1  # Mark as non-existent
    except (IOError, OSError) as e:
        print(f"Error during initial read of {state_path}: {e}", file=sys.stderr)
        # Still attempt to monitor

    while True:
        try:
            # Check if file exists now
            if not state_path.exists():
                if last_mtime != -1:  # It existed before, now deleted
                    print("{}", flush=True)  # Print empty object as it's gone
                    last_mtime = -1
                    last_content = "{}"
            else:
                current_mtime = state_path.stat().st_mtime
                if last_mtime == -1 or current_mtime != last_mtime:
                    # File created or modified
                    current_content = state_path.read_text()
                    if current_content != last_content:
                        print(_current_to_data(current_content), flush=True)
                        last_content = current_content
                    last_mtime = current_mtime

        except (IOError, OSError) as e:
            # Handle potential race conditions or permissions issues gracefully
            print(f"Error checking state file {state_path}: {e}", file=sys.stderr)
            # Reset mtime to force re-read attempt next cycle if error persists
            last_mtime = None
        except Exception as e:
            print(f"Unexpected error in monitoring loop: {e}", file=sys.stderr)

        time.sleep(1)  # Poll every second


def main():
    parser = argparse.ArgumentParser(description="Manage and display todos for Waybar.")
    subparsers = parser.add_subparsers(dest="command", help="Sub-command help")

    # Add command
    parser_add = subparsers.add_parser("add", help="Add a new todo")
    parser_add.add_argument("todo", type=str, help="The description of the todo")
    parser_add.set_defaults(func=handle_add)

    # Remove command
    parser_remove = subparsers.add_parser(
        "remove", help="Remove the current todo and select the next"
    )
    parser_remove.set_defaults(func=handle_remove)

    # Toggle command
    parser_toggle = subparsers.add_parser("toggle", help="Select the next todo")
    parser_toggle.set_defaults(func=handle_toggle)

    args = parser.parse_args()

    if hasattr(args, "func"):
        args.func(args)
    elif args.command is None:
        # Default mode: monitor the state file
        monitor_state_file(STATE_FILE)
    else:
        # Should not happen with argparse setup, but handle defensively
        parser.print_help()


if __name__ == "__main__":
    main()
