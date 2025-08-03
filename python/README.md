# AWS Network Firewall Automation

Python automation scripts for AWS Network Firewall management.

## Features

- Route table management via YAML configuration
- Firewall rule management and updates
- Configuration validation
- Dry-run capabilities for testing

## Usage

### Route Manager

```bash
uv run python route_manager.py --config ../config/routes.yaml --region ap-southeast-4
```

### Firewall Manager

```bash
uv run python firewall_manager.py --config ../config/firewall-rules.yaml --region ap-southeast-4
```

## Development

Install dependencies:
```bash
uv sync
```

Run tests:
```bash
uv run pytest
```

Format code:
```bash
uv run black .
uv run isort .
``` 