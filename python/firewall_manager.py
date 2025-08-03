#!/usr/bin/env python3
"""
AWS Network Firewall Manager

This script manages AWS Network Firewall configurations and rules.
It provides functionality to update firewall policies and rule groups.
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


class FirewallRule(BaseModel):
    """Model for a firewall rule."""
    name: str = Field(..., description="Rule name")
    priority: int = Field(..., description="Rule priority")
    action: str = Field(..., description="Rule action (ALLOW, DROP, ALERT)")
    source: str = Field(..., description="Source CIDR or ANY")
    destination: str = Field(..., description="Destination CIDR or ANY")
    protocol: str = Field(..., description="Protocol (TCP, UDP, ANY)")
    description: Optional[str] = Field(None, description="Rule description")


class FirewallPolicy(BaseModel):
    """Model for a firewall policy configuration."""
    name: str = Field(..., description="Policy name")
    description: Optional[str] = Field(None, description="Policy description")
    rules: List[FirewallRule] = Field(default_factory=list, description="List of rules")


class FirewallConfiguration(BaseModel):
    """Model for the complete firewall configuration."""
    policies: List[FirewallPolicy] = Field(default_factory=list, description="List of policies")


class FirewallManager:
    """Manages AWS Network Firewall operations."""

    def __init__(self, region: str = "ap-southeast-4"):
        """Initialize the firewall manager."""
        self.region = region
        try:
            self.networkfirewall_client = boto3.client("network-firewall", region_name=region)
        except NoCredentialsError:
            console.print("[red]Error: AWS credentials not found. Please configure your credentials.[/red]")
            sys.exit(1)

    def load_configuration(self, config_path: str) -> FirewallConfiguration:
        """Load firewall configuration from YAML file."""
        try:
            with open(config_path, "r") as file:
                config_data = yaml.safe_load(file)
            return FirewallConfiguration(**config_data)
        except FileNotFoundError:
            console.print(f"[red]Error: Configuration file '{config_path}' not found.[/red]")
            sys.exit(1)
        except yaml.YAMLError as e:
            console.print(f"[red]Error: Invalid YAML in configuration file: {e}[/red]")
            sys.exit(1)
        except Exception as e:
            console.print(f"[red]Error: Failed to load configuration: {e}[/red]")
            sys.exit(1)

    def get_firewall_policy(self, policy_name: str) -> Optional[Dict[str, Any]]:
        """Get firewall policy by name."""
        try:
            response = self.networkfirewall_client.describe_firewall_policy(
                FirewallPolicyName=policy_name
            )
            return response["FirewallPolicy"]
        except ClientError as e:
            if e.response["Error"]["Code"] == "ResourceNotFoundException":
                return None
            raise

    def create_firewall_policy(self, policy_config: FirewallPolicy) -> bool:
        """Create a new firewall policy."""
        try:
            # Convert rules to AWS format
            rules_source = self._convert_rules_to_aws_format(policy_config.rules)
            
            response = self.networkfirewall_client.create_firewall_policy(
                FirewallPolicyName=policy_config.name,
                FirewallPolicy={
                    "StatelessDefaultActions": ["aws:forward_to_sfe"],
                    "StatelessFragmentDefaultActions": ["aws:forward_to_sfe"],
                    "StatefulRuleGroupReferences": rules_source
                },
                Description=policy_config.description or ""
            )
            
            console.print(f"[green]✓ Created firewall policy: {policy_config.name}[/green]")
            return True
            
        except ClientError as e:
            console.print(f"[red]✗ Failed to create firewall policy {policy_config.name}: {e}[/red]")
            return False

    def update_firewall_policy(self, policy_config: FirewallPolicy) -> bool:
        """Update an existing firewall policy."""
        try:
            # Convert rules to AWS format
            rules_source = self._convert_rules_to_aws_format(policy_config.rules)
            
            response = self.networkfirewall_client.update_firewall_policy(
                FirewallPolicyName=policy_config.name,
                FirewallPolicy={
                    "StatelessDefaultActions": ["aws:forward_to_sfe"],
                    "StatelessFragmentDefaultActions": ["aws:forward_to_sfe"],
                    "StatefulRuleGroupReferences": rules_source
                },
                Description=policy_config.description or ""
            )
            
            console.print(f"[green]✓ Updated firewall policy: {policy_config.name}[/green]")
            return True
            
        except ClientError as e:
            console.print(f"[red]✗ Failed to update firewall policy {policy_config.name}: {e}[/red]")
            return False

    def _convert_rules_to_aws_format(self, rules: List[FirewallRule]) -> List[Dict[str, Any]]:
        """Convert firewall rules to AWS format."""
        rule_groups = []
        
        for rule in rules:
            # Create rule group for each rule
            rule_group_name = f"{rule.name}-rule-group"
            
            # Create the rule group first
            self._create_rule_group(rule_group_name, [rule])
            
            # Add reference to the rule group
            rule_groups.append({
                "ResourceArn": f"arn:aws:network-firewall:{self.region}:{self._get_account_id()}:stateful-rulegroup/{rule_group_name}"
            })
        
        return rule_groups

    def _create_rule_group(self, group_name: str, rules: List[FirewallRule]) -> bool:
        """Create a rule group for firewall rules."""
        try:
            # Convert rules to Suricata format
            suricata_rules = []
            for rule in rules:
                suricata_rule = self._convert_rule_to_suricata(rule)
                suricata_rules.append(suricata_rule)
            
            rules_string = "\n".join(suricata_rules)
            
            response = self.networkfirewall_client.create_rule_group(
                RuleGroupName=group_name,
                Type="STATEFUL",
                Capacity=100,
                RuleGroup={
                    "RulesSource": {
                        "RulesString": rules_string
                    }
                }
            )
            
            console.print(f"[green]✓ Created rule group: {group_name}[/green]")
            return True
            
        except ClientError as e:
            console.print(f"[red]✗ Failed to create rule group {group_name}: {e}[/red]")
            return False

    def _convert_rule_to_suricata(self, rule: FirewallRule) -> str:
        """Convert a firewall rule to Suricata format."""
        # Basic Suricata rule format
        action = "drop" if rule.action.upper() == "DROP" else "alert"
        source = "any" if rule.source.upper() == "ANY" else rule.source
        destination = "any" if rule.destination.upper() == "ANY" else rule.destination
        protocol = "any" if rule.protocol.upper() == "ANY" else rule.protocol.lower()
        
        suricata_rule = f"{action} {protocol} {source} any -> {destination} any (msg:\"{rule.description or rule.name}\"; sid:{rule.priority};)"
        
        return suricata_rule

    def _get_account_id(self) -> str:
        """Get AWS account ID."""
        try:
            sts_client = boto3.client("sts", region_name=self.region)
            response = sts_client.get_caller_identity()
            return response["Account"]
        except Exception:
            return "123456789012"  # Default fallback

    def list_firewall_policies(self) -> List[Dict[str, Any]]:
        """List all firewall policies."""
        try:
            response = self.networkfirewall_client.list_firewall_policies()
            return response["FirewallPolicies"]
        except ClientError as e:
            console.print(f"[red]✗ Failed to list firewall policies: {e}[/red]")
            return []

    def display_firewall_policy(self, policy_config: FirewallPolicy):
        """Display firewall policy information."""
        table = Table(title=f"Firewall Policy: {policy_config.name}")
        table.add_column("Priority", style="cyan")
        table.add_column("Action", style="magenta")
        table.add_column("Source", style="green")
        table.add_column("Destination", style="blue")
        table.add_column("Protocol", style="yellow")
        table.add_column("Description", style="white")

        for rule in policy_config.rules:
            table.add_row(
                str(rule.priority),
                rule.action,
                rule.source,
                rule.destination,
                rule.protocol,
                rule.description or ""
            )

        console.print(table)

    def validate_configuration(self, config: FirewallConfiguration) -> bool:
        """Validate the firewall configuration."""
        console.print("[bold]Validating configuration...[/bold]")
        
        for policy in config.policies:
            # Validate rules
            for rule in policy.rules:
                if not self._is_valid_action(rule.action):
                    console.print(f"[red]✗ Invalid action: {rule.action}[/red]")
                    return False
                
                if not self._is_valid_protocol(rule.protocol):
                    console.print(f"[red]✗ Invalid protocol: {rule.protocol}[/red]")
                    return False

        console.print("[green]✓ Configuration validation passed[/green]")
        return True

    def _is_valid_action(self, action: str) -> bool:
        """Validate firewall rule action."""
        valid_actions = ["ALLOW", "DROP", "ALERT"]
        return action.upper() in valid_actions

    def _is_valid_protocol(self, protocol: str) -> bool:
        """Validate protocol."""
        valid_protocols = ["TCP", "UDP", "ANY", "ICMP"]
        return protocol.upper() in valid_protocols

    def apply_configuration(self, config: FirewallConfiguration, dry_run: bool = False) -> bool:
        """Apply firewall configuration."""
        console.print("[bold]Applying firewall configuration...[/bold]")
        
        if dry_run:
            console.print("[yellow]DRY RUN MODE - No changes will be made[/yellow]")

        success_count = 0
        for policy_config in config.policies:
            console.print(f"\n[bold]Processing policy: {policy_config.name}[/bold]")
            
            # Check if policy exists
            existing_policy = self.get_firewall_policy(policy_config.name)
            
            if existing_policy:
                if not dry_run:
                    if self.update_firewall_policy(policy_config):
                        success_count += 1
                else:
                    console.print(f"[blue]Would update policy: {policy_config.name}[/blue]")
                    success_count += 1
            else:
                if not dry_run:
                    if self.create_firewall_policy(policy_config):
                        success_count += 1
                else:
                    console.print(f"[blue]Would create policy: {policy_config.name}[/blue]")
                    success_count += 1

        console.print(f"\n[bold]Summary:[/bold]")
        console.print(f"Successfully processed {success_count}/{len(config.policies)} policies")
        
        return success_count == len(config.policies)


def main():
    """Main function."""
    parser = argparse.ArgumentParser(description="AWS Network Firewall Manager")
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
        "--list-policies",
        action="store_true",
        help="List existing firewall policies"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose logging"
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Initialize firewall manager
    manager = FirewallManager(region=args.region)

    if args.list_policies:
        console.print("[bold]Listing firewall policies...[/bold]")
        policies = manager.list_firewall_policies()
        
        if policies:
            table = Table(title="Firewall Policies")
            table.add_column("Name", style="cyan")
            table.add_column("ARN", style="magenta")
            
            for policy in policies:
                table.add_row(
                    policy["Name"],
                    policy["Arn"]
                )
            
            console.print(table)
        else:
            console.print("[yellow]No firewall policies found[/yellow]")
        return

    # Load configuration
    console.print(f"[bold]Loading configuration from: {args.config}[/bold]")
    config = manager.load_configuration(args.config)

    # Validate configuration
    if not manager.validate_configuration(config):
        sys.exit(1)

    if args.validate_only:
        console.print("[green]✓ Configuration is valid[/green]")
        return

    # Apply configuration
    if manager.apply_configuration(config, dry_run=args.dry_run):
        if args.dry_run:
            console.print("[yellow]DRY RUN COMPLETED - No changes were made[/yellow]")
        else:
            console.print("[green]✓ Firewall configuration applied successfully[/green]")
    else:
        console.print("[red]✗ Failed to apply firewall configuration[/red]")
        sys.exit(1)


if __name__ == "__main__":
    main() 