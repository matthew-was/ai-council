#!/bin/bash

# AI Council Update Notifier
# Generates and delivers update notifications

set -e

# Configuration
REGISTRY_FILE=".vibe/skills/skills.json"
VERSION_CHECKER=".vibe/skills/version_checker.sh"
DEPENDENCY_CHECKER=".vibe/skills/dependency_checker.sh"
NOTIFICATION_DIR=".vibe/skills/notifications"
NOTIFICATION_LOG="$NOTIFICATION_DIR/notification_log.txt"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure notification directory exists
mkdir -p "$NOTIFICATION_DIR"

# Function to generate update notifications
generate_update_notifications() {
    echo -e "${BLUE}Generating update notifications...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    # Create timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local notification_file="$NOTIFICATION_DIR/update_notification_$timestamp.txt"
    
    # Start notification file
    echo "AI Council Update Notification" > "$notification_file"
    echo "================================" >> "$notification_file"
    echo "Generated: $(date)" >> "$notification_file"
    echo "" >> "$notification_file"
    
    # Check for updates
    if [[ -f "$VERSION_CHECKER" ]]; then
        echo "Version Updates:" >> "$notification_file"
        echo "----------------" >> "$notification_file"
        
        # Run version scan and capture output
        local scan_output
        scan_output=$("$VERSION_CHECKER" scan 2>&1)
        
        # Analyze scan output for updates
        if echo "$scan_output" | grep -q "up-to-date"; then
            echo "✅ All skills are up-to-date" >> "$notification_file"
        else
            echo "⚠️  Updates may be available" >> "$notification_file"
        fi
        
        echo "" >> "$notification_file"
    else
        echo "⚠️  Version checker not available" >> "$notification_file"
    fi
    
    # Check dependencies
    if [[ -f "$DEPENDENCY_CHECKER" ]]; then
        echo "Dependency Status:" >> "$notification_file"
        echo "------------------" >> "$notification_file"
        
        # Run dependency check
        local deps_output
        deps_output=$("$DEPENDENCY_CHECKER" all 2>&1)
        
        if echo "$deps_output" | grep -q "validated successfully"; then
            echo "✅ All dependencies validated" >> "$notification_file"
        else
            echo "❌ Dependency issues detected" >> "$notification_file"
        fi
        
        echo "" >> "$notification_file"
    else
        echo "⚠️  Dependency checker not available" >> "$notification_file"
    fi
    
    # Check for critical updates
    if [[ -f "$VERSION_CHECKER" ]]; then
        echo "Critical Updates:" >> "$notification_file"
        echo "----------------" >> "$notification_file"
        
        local critical_output
        critical_output=$("$VERSION_CHECKER" critical 2>&1)
        
        if echo "$critical_output" | grep -q "No critical updates"; then
            echo "✅ No critical updates pending" >> "$notification_file"
        else
            echo "❌ Critical updates detected" >> "$notification_file"
        fi
        
        echo "" >> "$notification_file"
    fi
    
    # Add recommendations
    echo "Recommendations:" >> "$notification_file"
    echo "---------------" >> "$notification_file"
    echo "• Review update notifications regularly" >> "$notification_file"
    echo "• Validate dependencies before changes" >> "$notification_file"
    echo "• Test updates in staging environment" >> "$notification_file"
    echo "• Backup registry before major updates" >> "$notification_file"
    
    # Log the notification
    echo "[$(date)] Generated update notification: $notification_file" >> "$NOTIFICATION_LOG"
    
    echo -e "${GREEN}✅ Update notification generated: $notification_file${NC}"
    
    # Display notification
    echo -e "${BLUE}Update Notification Summary:${NC}"
    cat "$notification_file"
    
    return 0
}

# Function to check for critical updates
check_critical_updates() {
    echo -e "${BLUE}Checking for critical updates...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    # Check version compatibility
    if [[ -f "$VERSION_CHECKER" ]]; then
        "$VERSION_CHECKER" critical
    else
        echo -e "${YELLOW}⚠️  Version checker not available for critical update detection${NC}"
    fi
    
    # Check dependency issues
    if [[ -f "$DEPENDENCY_CHECKER" ]]; then
        local deps_issues
        deps_issues=$("$DEPENDENCY_CHECKER" all 2>&1 | grep -c "issues" || echo "0")
        
        if [[ "$deps_issues" -gt 0 ]]; then
            echo -e "${RED}❌ Dependency issues detected${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}✅ No critical updates detected${NC}"
    return 0
}

# Function to monitor for updates
monitor_updates() {
    echo -e "${BLUE}Monitoring for updates...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    # This would be enhanced with actual monitoring logic
    # For now, we'll generate a notification
    generate_update_notifications
    
    echo -e "${GREEN}✅ Update monitoring complete${NC}"
    echo -e "${YELLOW}Note: Continuous monitoring would be set up separately${NC}"
    
    return 0
}

# Function to list recent notifications
list_notifications() {
    echo -e "${BLUE}Listing recent notifications...${NC}"
    
    if [[ ! -d "$NOTIFICATION_DIR" ]]; then
        echo -e "${YELLOW}No notifications found${NC}"
        return 0
    fi
    
    echo "Recent Notifications:"
    echo "===================="
    
    # List notification files
    ls -lt "$NOTIFICATION_DIR"/*.txt 2>/dev/null | head -10 | while read line; do
        echo "$line"
    done
    
    if [[ $? -ne 0 ]]; then
        echo -e "${YELLOW}No notifications found${NC}"
    fi
    
    return 0
}

# Function to show specific notification
show_notification() {
    local notification_file="$1"
    
    if [[ -z "$notification_file" ]]; then
        echo "Error: Notification file required"
        echo "Usage: $0 show <notification_file>"
        return 1
    fi
    
    local full_path="$NOTIFICATION_DIR/$notification_file"
    
    if [[ ! -f "$full_path" ]]; then
        echo -e "${RED}Error: Notification file not found: $full_path${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Showing notification: $notification_file${NC}"
    echo "=========================================="
    cat "$full_path"
    
    return 0
}

# Function to clear old notifications
clear_notifications() {
    local days="${1:-30}"  # Default: 30 days
    
    echo -e "${BLUE}Clearing notifications older than $days days...${NC}"
    
    if [[ ! -d "$NOTIFICATION_DIR" ]]; then
        echo -e "${YELLOW}No notifications to clear${NC}"
        return 0
    fi
    
    # Find and remove old notification files
    find "$NOTIFICATION_DIR" -name "*.txt" -type f -mtime +$days -exec rm -f {} \; 2>/dev/null
    
    local cleared_count=$(find "$NOTIFICATION_DIR" -name "*.txt" -type f -mtime +$days | wc -l 2>/dev/null)
    
    if [[ "$cleared_count" -gt 0 ]]; then
        echo -e "${GREEN}✅ Cleared $cleared_count old notification(s)${NC}"
    else
        echo -e "${YELLOW}No old notifications to clear${NC}"
    fi
    
    return 0
}

# Function to get notification statistics
notification_stats() {
    echo -e "${BLUE}Notification Statistics...${NC}"
    
    if [[ ! -d "$NOTIFICATION_DIR" ]]; then
        echo -e "${YELLOW}No notifications found${NC}"
        return 0
    fi
    
    local total_notifications=$(ls -1 "$NOTIFICATION_DIR"/*.txt 2>/dev/null | wc -l)
    local recent_notifications=$(find "$NOTIFICATION_DIR" -name "*.txt" -type f -mtime -7 2>/dev/null | wc -l)
    local log_entries=$(wc -l < "$NOTIFICATION_LOG" 2>/dev/null || echo "0")
    
    echo "Notification Statistics:"
    echo "======================="
    echo "Total notifications: $total_notifications"
    echo "Recent (7 days): $recent_notifications"
    echo "Log entries: $log_entries"
    echo "Storage used: $(du -sh "$NOTIFICATION_DIR" 2>/dev/null | cut -f1)"
    
    return 0
}

# Main function
main() {
    local command="$1"
    shift

    case "$command" in
        generate|create)
            generate_update_notifications
            ;;
        critical|check-critical)
            check_critical_updates
            ;;
        monitor|watch)
            monitor_updates
            ;;
        list|show-all)
            list_notifications
            ;;
        show)
            show_notification "$1"
            ;;
        clear)
            clear_notifications "$1"
            ;;
        stats|statistics)
            notification_stats
            ;;
        *)
            echo "AI Council Update Notifier"
            echo "========================="
            echo ""
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  generate, create        - Generate update notifications"
            echo "  critical, check-critical - Check for critical updates"
            echo "  monitor, watch          - Monitor for updates"
            echo "  list, show-all          - List recent notifications"
            echo "  show <file>            - Show specific notification"
            echo "  clear [days]           - Clear old notifications (default: 30 days)"
            echo "  stats, statistics       - Show notification statistics"
            echo ""
            echo "Examples:"
            echo "  $0 generate"
            echo "  $0 list"
            echo "  $0 show update_notification_20260319.txt"
            echo "  $0 clear 30"
            ;;
    esac
}

# Run main function
main "$@"
