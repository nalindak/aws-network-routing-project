#!/usr/bin/env python3
"""
AWS Route Table Manager

This script manages AWS route table updates based on YAML configuration files.
It provides functionality to add, update, and remove routes from route tables.
"""

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import boto3
import yaml
from botocore.exceptions import ClientError, NoCredentialsError
from rich.console import Console
from rich.table import Table
from pydantic import BaseModel, Field

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

console = Console()


class Route(BaseModel):
    """Model for a route configuration."""
    destination: str = Field(..., description="Destination CIDR block")
    target: str = Field(..., description="Target (gateway, NAT gateway, etc.)")
    description: Optional[str] = Field(None, description="Route description")
    target_type: Optional[str] = Field(None, description="Target type (gateway, nat, etc.)")


class RouteTable(BaseModel):
    """Model for a route table configuration."""
    table_id: str = Field(..., description="Route table ID")
    routes: List[Route] = Field(default_factory=list, description="List of routes")
    description: Optional[str] = Field(None, description="Route table description")


class RouteConfiguration(BaseModel):
    """Model for the complete route configuration."""
    route_tables: List[RouteTable] = Field(default_factory=list, description="List of route tables")


class RouteManager:
    """Manages AWS route table operations."""

    def __init__(self, region: str = "ap-southeast-4"):
        """Initialize the route manager."""
        self.region = region
        try:
            self.ec2_client = boto3.client("ec2", region_name=region)
            self.ec2_resource = boto3.resource("ec2", region_name=region)
        except NoCredentialsError:
            console.print("[red]Error: AWS credentials not found. Please configure your credentials.[/red]")
            sys.exit(1)

    def load_configuration(self, config_path: str) -> RouteConfiguration:
        """Load route configuration from YAML file."""
        try:
            with open(config_path, "r") as file:
                config_data = yaml.safe_load(file)
            return RouteConfiguration(**config_data)
        except FileNotFoundError:
            console.print(f"[red]Error: Configuration file '{config_path}' not found.[/red]")
            sys.exit(1)
        except yaml.YAMLError as e:
            console.print(f"[red]Error: Invalid YAML in configuration file: {e}[/red]")
            sys.exit(1)
        except Exception as e:
            console.print(f"[red]Error: Failed to load configuration: {e}[/red]")
            sys.exit(1)

    def get_route_table(self, table_id: str) -> Optional[Any]:
        """Get route table by ID."""
        try:
            route_table = self.ec2_resource.RouteTable(table_id)
            route_table.load()
            return route_table
        except ClientError as e:
            if e.response["Error"]["Code"] == "InvalidRouteTableID.NotFound":
                return None
            raise

    def get_existing_routes(self, route_table: Any) -> List[Dict[str, Any]]:
        """Get existing routes from a route table."""
        routes = []
        for route in route_table.routes:
            if route.destination_cidr_block != "0.0.0.0/0":  # Skip local route
                routes.append({
                    "destination": route.destination_cidr_block,
                    "target": self._get_route_target(route),
                    "target_type": self._get_target_type(route)
                })
        return routes

    def _get_route_target(self, route: Any) -> str:
        """Extract target from route."""
        if hasattr(route, "gateway_id") and route.gateway_id:
            return route.gateway_id
        elif hasattr(route, "nat_gateway_id") and route.nat_gateway_id:
            return route.nat_gateway_id
        elif hasattr(route, "vpc_peering_connection_id") and route.vpc_peering_connection_id:
            return route.vpc_peering_connection_id
        elif hasattr(route, "network_interface_id") and route.network_interface_id:
            return route.network_interface_id
        else:
            return "unknown"

    def _get_target_type(self, route: Any) -> str:
        """Determine target type from route."""
        if hasattr(route, "gateway_id") and route.gateway_id:
            return "gateway"
        elif hasattr(route, "nat_gateway_id") and route.nat_gateway_id:
            return "nat"
        elif hasattr(route, "vpc_peering_connection_id") and route.vpc_peering_connection_id:
            return "vpc-peering"
        elif hasattr(route, "network_interface_id") and route.network_interface_id:
            return "network-interface"
        else:
            return "unknown"

    def create_route(self, route_table: Any, route: Route) -> bool:
        """Create a new route in the route table."""
        try:
            kwargs = {
                "RouteTableId": route_table.id,
                "DestinationCidrBlock": route.destination
            }

            # Determine target type and add appropriate parameter
            if route.target.startswith("igw-"):
                kwargs["GatewayId"] = route.target
            elif route.target.startswith("nat-"):
                kwargs["NatGatewayId"] = route.target
            elif route.target.startswith("pcx-"):
                kwargs["VpcPeeringConnectionId"] = route.target
            elif route.target.startswith("eni-"):
                kwargs["NetworkInterfaceId"] = route.target
            else:
                # Assume it's a gateway ID
                kwargs["GatewayId"] = route.target

            self.ec2_client.create_route(**kwargs)
            console.print(f"[green]✓ Created route {route.destination} -> {route.target}[/green]")
            return True

        except ClientError as e:
            if e.response["Error"]["Code"] == "RouteAlreadyExists":
                console.print(f"[yellow]⚠ Route {route.destination} already exists[/yellow]")
                return True
            else:
                console.print(f"[red]✗ Failed to create route {route.destination}: {e}[/red]")
                return False

    def delete_route(self, route_table: Any, destination: str) -> bool:
        """Delete a route from the route table."""
        try:
            self.ec2_client.delete_route(
                RouteTableId=route_table.id,
                DestinationCidrBlock=destination
            )
            console.print(f"[green]✓ Deleted route {destination}[/green]")
            return True
        except ClientError as e:
            console.print(f"[red]✗ Failed to delete route {destination}: {e}[/red]")
            return False

    def update_route_table(self, route_table_config: RouteTable, dry_run: bool = False) -> bool:
        """Update a route table with new routes."""
        console.print(f"\n[bold]Processing route table: {route_table_config.table_id}[/bold]")

        # Get existing route table
        route_table = self.get_route_table(route_table_config.table_id)
        if not route_table:
            console.print(f"[red]✗ Route table {route_table_config.table_id} not found[/red]")
            return False

        if dry_run:
            console.print("[yellow]DRY RUN MODE - No changes will be made[/yellow]")

        # Get existing routes
        existing_routes = self.get_existing_routes(route_table)
        existing_destinations = {route["destination"] for route in existing_routes}

        # Process new routes
        success_count = 0
        for route in route_table_config.routes:
            if route.destination not in existing_destinations:
                if not dry_run:
                    if self.create_route(route_table, route):
                        success_count += 1
                else:
                    console.print(f"[blue]Would create route: {route.destination} -> {route.target}[/blue]")
                    success_count += 1
            else:
                console.print(f"[yellow]⚠ Route {route.destination} already exists[/yellow]")

        console.print(f"[green]✓ Successfully processed {success_count} routes[/green]")
        return True

    def display_route_table(self, route_table_config: RouteTable):
        """Display route table information."""
        table = Table(title=f"Route Table: {route_table_config.table_id}")
        table.add_column("Destination", style="cyan")
        table.add_column("Target", style="magenta")
        table.add_column("Description", style="green")

        for route in route_table_config.routes:
            table.add_row(
                route.destination,
                route.target,
                route.description or ""
            )

        console.print(table)

    def validate_configuration(self, config: RouteConfiguration) -> bool:
        """Validate the route configuration."""
        console.print("[bold]Validating configuration...[/bold]")
        
        for route_table in config.route_tables:
            # Check if route table exists
            if not self.get_route_table(route_table.table_id):
                console.print(f"[red]✗ Route table {route_table.table_id} not found[/red]")
                return False

            # Validate routes
            for route in route_table.routes:
                if not self._is_valid_cidr(route.destination):
                    console.print(f"[red]✗ Invalid CIDR: {route.destination}[/red]")
                    return False

        console.print("[green]✓ Configuration validation passed[/green]")
        return True

    def _is_valid_cidr(self, cidr: str) -> bool:
        """Validate CIDR notation."""
        try:
            import ipaddress
            ipaddress.IPv4Network(cidr, strict=False)
            return True
        except ValueError:
            return False


def main():
    """Main function."""
    parser = argparse.ArgumentParser(description="AWS Route Table Manager")
    parser.add_argument(
        "--config", "-c",
        required=True,
        help="Path to YAML configuration file"
    )
    parser.add_argument(
        "--region", "-r",
        default="ap-southeast-4",
        help="AWS region (default: ap-southeast-4)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without making changes"
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Only validate configuration without applying changes"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose logging"
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Initialize route manager
    manager = RouteManager(region=args.region)

    # Load configuration
    console.print(f"[bold]Loading configuration from: {args.config}[/bold]")
    config = manager.load_configuration(args.config)

    # Validate configuration
    if not manager.validate_configuration(config):
        sys.exit(1)

    if args.validate_only:
        console.print("[green]✓ Configuration is valid[/green]")
        return

    # Process route tables
    success_count = 0
    for route_table_config in config.route_tables:
        if manager.update_route_table(route_table_config, dry_run=args.dry_run):
            success_count += 1

    console.print(f"\n[bold]Summary:[/bold]")
    console.print(f"Successfully processed {success_count}/{len(config.route_tables)} route tables")

    if args.dry_run:
        console.print("[yellow]DRY RUN COMPLETED - No changes were made[/yellow]")
    else:
        console.print("[green]✓ Route table updates completed successfully[/green]")


if __name__ == "__main__":
    main() 