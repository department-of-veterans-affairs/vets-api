#!/bin/bash
# Helper script to stop all MHV staging tunnels
# Usage: ./modules/mobile/bin/stop_mhv_tunnels.sh

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Stopping MHV tunnels...${NC}\n"

# Check if PID directory exists
if [ -f /tmp/mhv_tunnels_pid_dir ]; then
    PID_DIR=$(cat /tmp/mhv_tunnels_pid_dir)

    if [ -d "$PID_DIR" ]; then
        # Kill processes from PID files
        for pid_file in "$PID_DIR"/*.pid; do
            if [ -f "$pid_file" ]; then
                service_name=$(basename "$pid_file" .pid)
                pid=$(cat "$pid_file")

                if ps -p $pid > /dev/null 2>&1; then
                    kill $pid 2>/dev/null
                    echo -e "${GREEN}✓ Stopped $service_name tunnel (PID: $pid)${NC}"
                fi
            fi
        done

        # Clean up PID directory
        rm -rf "$PID_DIR"
        rm -f /tmp/mhv_tunnels_pid_dir
    fi
fi

# Also kill any socat processes on our ports (fallback)
for port in 2003 2004 2006; do
    if lsof -ti :$port &> /dev/null; then
        service=""
        case $port in
            2003) service="Secure Messaging" ;;
            2004) service="Medications" ;;
            2006) service="Medical Records" ;;
        esac

        lsof -ti :$port | xargs kill -9 2>/dev/null
        echo -e "${GREEN}✓ Stopped $service tunnel on port $port${NC}"
    fi
done

echo -e "\n${GREEN}All MHV tunnels stopped${NC}"

# Ask if they want to stop SOCKS proxy too
echo -e "\n${YELLOW}Stop SOCKS proxy too? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    vtk socks off
    echo -e "${GREEN}✓ SOCKS proxy stopped${NC}"
fi

echo -e "\n${GREEN}Done!${NC}\n"
