import sys
from pathlib import Path
import yaml


def validate_manifest(path: Path) -> bool:
    try:
        with open(path, 'r') as f:
            docs = list(yaml.safe_load_all(f))
        for doc in docs:
            if not isinstance(doc, dict):
                print(f"{path}: document is not a mapping", file=sys.stderr)
                return False
            if 'apiVersion' not in doc or 'kind' not in doc:
                print(f"{path}: missing apiVersion or kind", file=sys.stderr)
                return False
    except yaml.YAMLError as e:
        print(f"{path}: YAML error: {e}", file=sys.stderr)
        return False
    return True


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <directory>", file=sys.stderr)
        return 1
    directory = Path(sys.argv[1])
    if not directory.is_dir():
        print(f"{directory} is not a directory", file=sys.stderr)
        return 1
    success = True
    for path in directory.glob('*.yaml'):
        if not validate_manifest(path):
            success = False
    return 0 if success else 1


if __name__ == '__main__':
    raise SystemExit(main())
