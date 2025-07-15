#!/bin/bash

# Code Sync Tool - Synchronize local code to Ubuntu server
# Usage: ./sync-code.sh [environment] [options]

# Configuration - Edit these variables for your setup
DEFAULT_SERVER="your-server.com"
DEFAULT_USER="ubuntu"
DEFAULT_REMOTE_PATH="/home/ubuntu/app"
DEFAULT_LOCAL_PATH="."
SSH_KEY_PATH="~/.ssh/id_rsa"
SSH_PORT="22"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default exclude patterns
EXCLUDE_PATTERNS=(
    ".git/"
    "node_modules/"
    ".env"
    ".env.local"
    ".env.production"
    "*.log"
    "*.tmp"
    ".DS_Store"
    "Thumbs.db"
    "__pycache__/"
    "*.pyc"
    ".vscode/"
    ".idea/"
    "dist/"
    "build/"
    "coverage/"
    ".nyc_output/"
    "*.backup"
    "*.swp"
    "*.swo"
)

# Function to display usage
show_usage() {
    echo -e "${BLUE}Code Sync Tool${NC}"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --server SERVER     Remote server hostname or IP"
    echo "  -u, --user USER         Remote username (default: ubuntu)"
    echo "  -r, --remote-path PATH  Remote directory path"
    echo "  -l, --local-path PATH   Local directory path (default: current directory)"
    echo "  -p, --port PORT         SSH port (default: 22)"
    echo "  -k, --key-path PATH     SSH private key path"
    echo "  -e, --exclude PATTERN   Additional exclude pattern"
    echo "  -n, --dry-run          Show what would be transferred without actually doing it"
    echo "  -v, --verbose          Verbose output"
    echo "  -d, --delete           Delete files on remote that don't exist locally"
    echo "  -c, --compress         Enable compression during transfer"
    echo "  -w, --watch            Watch for file changes and auto-sync"
    echo "  -i, --interval SECONDS  Watch interval in seconds (default: 2)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s myserver.com -r /var/www/myapp"
    echo "  $0 --server 192.168.1.100 --user deploy --remote-path /opt/app --dry-run"
    echo "  $0 -s myserver.com -r /home/user/project -e '*.pdf' -e 'temp/'"
    echo "  $0 -s myserver.com -r /var/www/myapp --watch"
    echo "  $0 -s myserver.com -r /var/www/myapp --watch --interval 5"
}

# Function to log messages
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate SSH connection
validate_ssh_connection() {
    local server=$1
    local user=$2
    local port=$3
    local key_path=$4
    
    log "Testing SSH connection to $user@$server:$port..."
    
    if [[ -n "$key_path" ]]; then
        ssh -i "$key_path" -p "$port" -o ConnectTimeout=10 -o BatchMode=yes "$user@$server" exit 2>/dev/null
    else
        ssh -p "$port" -o ConnectTimeout=10 -o BatchMode=yes "$user@$server" exit 2>/dev/null
    fi
    
    if [[ $? -eq 0 ]]; then
        log "SSH connection successful"
        return 0
    else
        log_error "SSH connection failed"
        return 1
    fi
}

# Function to get directory checksum (for change detection)
get_directory_checksum() {
    local dir=$1
    # Create checksum of all files (modified time + size)
    find "$dir" -type f \( ! -path '*/.git/*' ! -path '*/node_modules/*' ! -name '*.log' \) -exec stat -c '%n %Y %s' {} \; 2>/dev/null | sort | md5sum | cut -d' ' -f1
}

# Function to watch for file changes
watch_and_sync() {
    local server=$1
    local user=$2
    local remote_path=$3
    local local_path=$4
    local port=$5
    local key_path=$6
    local verbose=$7
    local delete=$8
    local compress=$9
    local interval=${10}
    
    log "Starting file watcher mode (interval: ${interval}s)"
    log "Press Ctrl+C to stop watching"
    
    local last_checksum=""
    local sync_count=0
    
    # Initial sync
    log "Performing initial sync..."
    rsync_cmd=$(build_rsync_command "$server" "$user" "$remote_path" "$local_path" "$port" "$key_path" "false" "$verbose" "$delete" "$compress")
    eval "$rsync_cmd" >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        log "Initial sync completed"
        sync_count=$((sync_count + 1))
        last_checksum=$(get_directory_checksum "$local_path")
    else
        log_error "Initial sync failed"
        return 1
    fi
    
    # Watch loop
    while true; do
        sleep "$interval"
        
        current_checksum=$(get_directory_checksum "$local_path")
        
        if [[ "$current_checksum" != "$last_checksum" ]]; then
            log "Changes detected, syncing..."
            
            rsync_cmd=$(build_rsync_command "$server" "$user" "$remote_path" "$local_path" "$port" "$key_path" "false" "$verbose" "$delete" "$compress")
            eval "$rsync_cmd" >/dev/null 2>&1
            
            if [[ $? -eq 0 ]]; then
                sync_count=$((sync_count + 1))
                log "Sync completed (total syncs: $sync_count)"
                last_checksum="$current_checksum"
            else
                log_error "Sync failed"
            fi
        fi
    done
}

# Function to setup signal handlers for watch mode
setup_signal_handlers() {
    trap 'log "Stopping file watcher..."; exit 0' INT TERM
}
build_rsync_command() {
    local server=$1
    local user=$2
    local remote_path=$3
    local local_path=$4
    local port=$5
    local key_path=$6
    local dry_run=$7
    local verbose=$8
    local delete=$9
    local compress=${10}
    
    local cmd="rsync -avz"
    
    # Add options
    [[ "$dry_run" == "true" ]] && cmd+=" --dry-run"
    [[ "$verbose" == "true" ]] && cmd+=" --verbose" || cmd+=" --quiet"
    [[ "$delete" == "true" ]] && cmd+=" --delete"
    [[ "$compress" == "true" ]] && cmd+=" --compress"
    
    # Add progress and human-readable output
    cmd+=" --progress --human-readable"
    
    # Add exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        cmd+=" --exclude='$pattern'"
    done
    
    # Add custom exclude patterns
    for pattern in "${CUSTOM_EXCLUDES[@]}"; do
        cmd+=" --exclude='$pattern'"
    done
    
    # SSH options
    local ssh_opts="-p $port"
    [[ -n "$key_path" ]] && ssh_opts+=" -i $key_path"
    cmd+=" -e 'ssh $ssh_opts'"
    
    # Add source and destination
    cmd+=" '$local_path/' '$user@$server:$remote_path/'"
    
    echo "$cmd"
}

# Parse command line arguments
parse_args() {
    CUSTOM_EXCLUDES=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--server)
                SERVER="$2"
                shift 2
                ;;
            -u|--user)
                USER="$2"
                shift 2
                ;;
            -r|--remote-path)
                REMOTE_PATH="$2"
                shift 2
                ;;
            -l|--local-path)
                LOCAL_PATH="$2"
                shift 2
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -k|--key-path)
                KEY_PATH="$2"
                shift 2
                ;;
            -e|--exclude)
                CUSTOM_EXCLUDES+=("$2")
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--delete)
                DELETE=true
                shift
                ;;
            -c|--compress)
                COMPRESS=true
                shift
                ;;
            -w|--watch)
                WATCH=true
                shift
                ;;
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Set defaults
    SERVER=${SERVER:-$DEFAULT_SERVER}
    USER=${USER:-$DEFAULT_USER}
    REMOTE_PATH=${REMOTE_PATH:-$DEFAULT_REMOTE_PATH}
    LOCAL_PATH=${LOCAL_PATH:-$DEFAULT_LOCAL_PATH}
    PORT=${PORT:-$SSH_PORT}
    KEY_PATH=${KEY_PATH:-$SSH_KEY_PATH}
    DRY_RUN=${DRY_RUN:-false}
    VERBOSE=${VERBOSE:-false}
    DELETE=${DELETE:-false}
    COMPRESS=${COMPRESS:-false}
    WATCH=${WATCH:-false}
    INTERVAL=${INTERVAL:-2}
    
    # Validate interval
    if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -lt 1 ]]; then
        log_error "Invalid interval: $INTERVAL (must be a positive integer)"
        exit 1
    fi
    
    # Validate required tools
    if ! command_exists rsync; then
        log_error "rsync is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists ssh; then
        log_error "ssh is not installed. Please install it first."
        exit 1
    fi
    
    # Validate required parameters
    if [[ -z "$SERVER" || -z "$REMOTE_PATH" ]]; then
        log_error "Server and remote path are required"
        show_usage
        exit 1
    fi
    
    # Validate local path exists
    if [[ ! -d "$LOCAL_PATH" ]]; then
        log_error "Local path does not exist: $LOCAL_PATH"
        exit 1
    fi
    
    # Expand tilde in key path
    KEY_PATH=$(eval echo "$KEY_PATH")
    
    # Validate SSH key if specified
    if [[ -n "$KEY_PATH" && ! -f "$KEY_PATH" ]]; then
        log_error "SSH key file does not exist: $KEY_PATH"
        exit 1
    fi
    
    # Display sync information
    echo -e "${BLUE}=== Code Sync Configuration ===${NC}"
    echo "Local path:  $LOCAL_PATH"
    echo "Remote:      $USER@$SERVER:$REMOTE_PATH"
    echo "SSH port:    $PORT"
    echo "SSH key:     ${KEY_PATH:-"default"}"
    echo "Dry run:     $DRY_RUN"
    echo "Delete:      $DELETE"
    echo "Compress:    $COMPRESS"
    echo "Watch mode:  $WATCH"
    [[ "$WATCH" == "true" ]] && echo "Interval:    ${INTERVAL}s"
    echo ""
    
    # Validate SSH connection
    if ! validate_ssh_connection "$SERVER" "$USER" "$PORT" "$KEY_PATH"; then
        exit 1
    fi
    
    # Check if watch mode is enabled
    if [[ "$WATCH" == "true" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_error "Watch mode cannot be used with dry-run"
            exit 1
        fi
        
        setup_signal_handlers
        watch_and_sync "$SERVER" "$USER" "$REMOTE_PATH" "$LOCAL_PATH" "$PORT" "$KEY_PATH" "$VERBOSE" "$DELETE" "$COMPRESS" "$INTERVAL"
        return
    fi
    
    # Build and execute rsync command
    rsync_cmd=$(build_rsync_command "$SERVER" "$USER" "$REMOTE_PATH" "$LOCAL_PATH" "$PORT" "$KEY_PATH" "$DRY_RUN" "$VERBOSE" "$DELETE" "$COMPRESS")
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN - No files will be transferred"
    fi
    
    log "Starting synchronization..."
    echo "Command: $rsync_cmd"
    echo ""
    
    # Execute the command
    eval "$rsync_cmd"
    
    if [[ $? -eq 0 ]]; then
        log "Synchronization completed successfully"
    else
        log_error "Synchronization failed"
        exit 1
    fi
}

# Parse arguments and run main function
parse_args "$@"
main
