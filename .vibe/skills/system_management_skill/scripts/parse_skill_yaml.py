#!/usr/bin/env python3

import yaml
import sys
import os

def parse_skill_metadata(skill_file):
    """Parse YAML metadata from SKILL.md file"""
    try:
        with open(skill_file, 'r') as f:
            content = f.read()

        # Extract YAML frontmatter
        if content.startswith('---'):
            yaml_end = content.find('---', 3)
            if yaml_end == -1:
                print("Error: Unclosed YAML frontmatter", file=sys.stderr)
                return None
            yaml_content = content[3:yaml_end].strip()
            data = yaml.safe_load(yaml_content)
            return data
        else:
            print("Error: No YAML frontmatter found", file=sys.stderr)
            return None
    except Exception as e:
        print(f"Error parsing YAML: {e}", file=sys.stderr)
        return None

def main():
    if len(sys.argv) != 2:
        print("Usage: parse_skill_yaml.py <skill_file>", file=sys.stderr)
        sys.exit(1)

    skill_file = sys.argv[1]
    data = parse_skill_metadata(skill_file)

    if data:
        # Output in format: key=value
        print(f"name={data.get('name', '')}")
        print(f"description={data.get('description', '')}")
        if 'metadata' in data:
            print(f"version={data['metadata'].get('version', '')}")
            print(f"author={data['metadata'].get('author', '')}")
            print(f"license={data['metadata'].get('license', '')}")
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
