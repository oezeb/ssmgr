#!/usr/bin/env python3

import argparse
import sys
import subprocess


def run_command(command, check=True):
    """Run shell command and return result"""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, check=check)
        return result.stdout.strip(), result.stderr.strip()
    except subprocess.CalledProcessError as e:
        if check:
            raise
        return "", e.stderr
    
def create_parser():

    # Main parser
    parser = argparse.ArgumentParser(
        prog='ssmgr',
        description='Shadowsocks Manager - User and Service Management Tool'
    )
    
    # Create subparsers for main commands
    subparsers = parser.add_subparsers(
        dest='command',
        help='Available commands',
        metavar='user|quota|validity|service'
    )

    # ========== USER SUBCOMMAND ==========
    user_parser = subparsers.add_parser('user', help='User management commands')
    user_subparsers = user_parser.add_subparsers(
        dest='user_action',
        help='User actions',
        metavar='ls|add|remove'
    )
    
    # user ls
    user_subparsers.add_parser('ls', help='List all users')
    
    # user add
    user_add_parser = user_subparsers.add_parser('add', help='Add a new user')
    user_add_parser.add_argument('port', type=int, help='Port number')
    user_add_parser.add_argument('-u', '--username', required=True, help='User Name')
    user_add_parser.add_argument('-p', '--password', help='Password (auto-generated if not provided)')
    user_add_parser.add_argument('-d', '--days', type=int, help='Expiration in days from now')
    user_add_parser.add_argument('-q', '--quota', type=int, help='Quota in GB')
    
    # user remove
    user_remove_parser = user_subparsers.add_parser('remove', help='Remove a user')
    user_remove_parser.add_argument('port', type=int, help='Port number')
    
    # ========== QUOTA SUBCOMMAND ==========
    quota_parser = subparsers.add_parser('quota', help='Quota management commands')
    quota_subparsers = quota_parser.add_subparsers(
        dest='quota_action',
        help='Quota actions',
        metavar='add|remove|reset|status'
    )
    
    # quota add
    quota_add_parser = quota_subparsers.add_parser('add', help='Add quota to user')
    quota_add_parser.add_argument('port', type=int, help='Port number')
    quota_add_parser.add_argument('-q', '--quota', type=int, help='Quota in GB')
    
    # quota remove
    quota_remove_parser = quota_subparsers.add_parser('remove', help='Remove quota from user')
    quota_remove_parser.add_argument('port', type=int, help='Port number')
    
    # quota reset
    quota_reset_parser = quota_subparsers.add_parser('reset', help='Reset user quota')
    quota_reset_parser.add_argument('port', type=int, help='Port number')
    quota_reset_parser.add_argument('-q', '--quota', type=int, help='New quota in GB')
    
    # quota status
    quota_status_parser = quota_subparsers.add_parser('status', help='Show quota status')
    quota_status_parser.add_argument('port', type=int, help='Port number')
    
    # ========== SERVICE SUBCOMMAND ==========
    service_parser = subparsers.add_parser('service', help='Service management commands')
    service_parser.add_argument('port', type=int, help='Port number')
    service_parser.add_argument(
        'action',
        choices=['start', 'stop', 'restart', 'status', 'enable', 'disable', 'logs'],
        help='Service action to perform'
    )

    # ========== CHECK-EXPIRED SUBCOMMAND ==========
    subparsers.add_parser('check-expired', help='Check and handle expired users')
    
    return parser

def handle_user_commands(args):
    """Handle user subcommands"""
    if args.user_action == 'ls':
        print("Listing all users...")
       
        cmd = "/etc/ssmgr/user ls"
        stdout, stderr = run_command(cmd, False)
        print(stdout or stderr)
        
    elif args.user_action == 'add':
        print(f"Adding user:")
        print(f"  Port: {args.port}")
        print(f"  User: {args.username}")
        print(f"  Password: {args.password or 'auto-generated'}")
        print(f"  Days: {args.days or 'no expiration'}")
        print(f"  Quota(GB): {args.quota or 'no quota'}")
        
        cmd = f"/etc/ssmgr/user add -p {args.port} -u {args.username}"
        if args.password:
            cmd += f" -k {args.password}"
        if args.days:
            cmd += f" -d {args.days}"
        if args.quota:
            cmd += f" -q {args.quota}"
        stdout, stderr = run_command(cmd, False)
        print(stdout or stderr)

    elif args.user_action == 'remove':
        print(f"Removing user on port {args.port}")
        
        cmd = f"/etc/ssmgr/user remove -p {args.port}"
        stdout, stderr = run_command(cmd, False)
        print(stdout or stderr)
        
    else:
        print("Error: No user action specified")
        return False
    
    return True

def handle_quota_commands(args):
    """Handle quota subcommands"""
    if args.quota_action == 'add':
        print(f"Adding quota to port {args.port}: {args.quota or 'default'} GB")

        cmd = f"/etc/ssmgr/quota add -p {args.port}"
        if args.quota:
            cmd += f" -q {args.quota}"
        stdout, stderr = run_command(cmd, False)
        print(stdout or stderr)
        
    elif args.quota_action == 'remove':
        print(f"Removing quota from port {args.port}")
        
        cmd = f"/etc/ssmgr/quota remove -p {args.port}"
        stdout, stderr = run_command(cmd, False)
        print(stdout or stderr)
        
    elif args.quota_action == 'reset':
        print(f"Resetting quota for port {args.port}: {args.quota or 'default'} GB")
        
        cmd = f"/etc/ssmgr/quota reset -p {args.port}"
        if args.quota:
            cmd += f" -q {args.quota}"
        stdout, stderr = run_command(cmd, False)
        print(stdout or stderr)
        
    elif args.quota_action == 'status':
        print(f"Quota status for port {args.port}")
        
        cmd = f"/etc/ssmgr/quota status -p {args.port}"
        stdout, stderr = run_command(cmd, False)
        print(stdout or stderr)
        
    else:
        print("Error: No quota action specified")
        return False
    
    return True

def handle_service_commands(args):
    """Handle service subcommands"""
    print(f"Service action: {args.action} for port {args.port}")
    
    cmd = f"/etc/ssmgr/service {args.action} {args.port}"
    stdout, stderr = run_command(cmd, False)
    print(stdout or stderr)
    return True

def handle_check_expired_commands(_):
    """Handle check expired subcommands"""
    print("Checking for expired sessions")
    
    cmd = "/etc/ssmgr/user check-expired"
    stdout, stderr = run_command(cmd, False)
    print(stdout or stderr)
    return True

def main():
    parser = create_parser()
    
    # Parse arguments
    args = parser.parse_args()

    # If no command provided, show help
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Route to appropriate handler
    success = False
    
    if args.command == 'user':
        success = handle_user_commands(args)
    elif args.command == 'quota':
        success = handle_quota_commands(args)
    elif args.command == 'service':
        success = handle_service_commands(args)
    elif args.command == 'check-expired':
        success = handle_check_expired_commands(args)
    else:
        print(f"Unknown command: {args.command}")
        parser.print_help()
        sys.exit(1)
    
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()