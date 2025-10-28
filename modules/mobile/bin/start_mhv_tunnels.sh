#!/bin/bash
# Helper script to start all MHV staging tunnels
# Usage: ./modules/mobile/bin/start_mhv_tunnels.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}MHV Staging Tunnels Setup${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Check if socat is installed
if ! command -v socat &> /dev/null; then
    echo -e "${RED}❌ Error: socat is not installed${NC}"
    echo -e "Install with: ${YELLOW}brew install socat${NC}"
    exit 1
fi

# Check if vtk is available
if ! command -v vtk &> /dev/null; then
    echo -e "${RED}❌ Error: vtk is not available${NC}"
    echo -e "Make sure you have SOCKS proxy access configured"
    exit 1
fi

# Check if SOCKS proxy is running on port 2001
if ! lsof -i :2001 &> /dev/null; then
    echo -e "${YELLOW}⚠️  SOCKS proxy not detected on port 2001${NC}"
    echo -e "Starting SOCKS proxy..."
    vtk socks on
    sleep 2

    if ! lsof -i :2001 &> /dev/null; then
        echo -e "${RED}❌ Failed to start SOCKS proxy${NC}"
        echo -e "Try manually: ${YELLOW}vtk socks on${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ SOCKS proxy started${NC}\n"
else
    echo -e "${GREEN}✓ SOCKS proxy already running${NC}\n"
fi

# Check if ports are already in use
PORTS_IN_USE=()
for port in 2003 2004 2006; do
    if lsof -i :$port &> /dev/null; then
        PORTS_IN_USE+=($port)
    fi
done

if [ ${#PORTS_IN_USE[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  The following ports are already in use: ${PORTS_IN_USE[*]}${NC}"
    echo -e "Kill existing processes? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        for port in "${PORTS_IN_USE[@]}"; do
            echo -e "Killing process on port $port..."
            lsof -ti :$port | xargs kill -9 2>/dev/null || true
        done
        sleep 1
    else
        echo -e "${RED}❌ Aborted - ports still in use${NC}"
        exit 1
    fi
fi

# Create a temporary directory for PID files
PID_DIR="/tmp/mhv_tunnels_$$"
mkdir -p "$PID_DIR"

echo -e "${GREEN}Starting MHV tunnels...${NC}\n"

# Function to start a tunnel
start_tunnel() {
    local port=$1
    local remote_port=$2
    local service_name=$3

    echo -e "Starting ${YELLOW}$service_name${NC} tunnel (port $port -> fwdproxy:$remote_port)..."
    socat TCP-LISTEN:$port,fork,reuseaddr SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:$remote_port,socksport=2001 &
    echo $! > "$PID_DIR/$service_name.pid"

    # Wait a moment and verify it started
    sleep 1
    if lsof -i :$port &> /dev/null; then
        echo -e "${GREEN}✓ $service_name tunnel started on port $port${NC}"
    else
        echo -e "${RED}❌ Failed to start $service_name tunnel${NC}"
        return 1
    fi
}

# Start tunnels for each service
start_tunnel 2003 4428 "Secure Messaging"
start_tunnel 2004 4426 "Medications"
start_tunnel 2006 4499 "Medical Records"

# Save PID directory path for cleanup script
echo "$PID_DIR" > /tmp/mhv_tunnels_pid_dir

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}All tunnels started successfully!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "Port mappings:"
echo -e "  ${YELLOW}2003${NC} -> Secure Messaging (fwdproxy-staging.vfs.va.gov:4428)"
echo -e "  ${YELLOW}2004${NC} -> Medications      (fwdproxy-staging.vfs.va.gov:4426)"
echo -e "  ${YELLOW}2006${NC} -> Medical Records  (fwdproxy-staging.vfs.va.gov:4499)"

echo -e "\n${GREEN}Next steps:${NC}"
echo -e "  1. Make sure ${YELLOW}settings.local.yml${NC} is configured for MHV"
echo -e "  2. Enable dev cache: ${YELLOW}bin/rails dev:cache${NC}"
echo -e "  3. Generate a token: ${YELLOW}bundle exec rake mobile:generate_mhv_token user_number=81${NC}"
echo -e "  4. Start vets-api: ${YELLOW}bundle exec rails s${NC}"

echo -e "\n${GREEN}To stop tunnels:${NC}"
echo -e "  ${YELLOW}./modules/mobile/bin/stop_mhv_tunnels.sh${NC}"
echo -e "  or press ${YELLOW}Ctrl+C${NC} and run the stop script to clean up\n"

# Wait for Ctrl+C
trap 'echo -e "\n${YELLOW}Stopping tunnels...${NC}"; ./modules/mobile/bin/stop_mhv_tunnels.sh 2>/dev/null || { for pid in $(cat $PID_DIR/*.pid 2>/dev/null); do kill $pid 2>/dev/null || true; done; rm -rf $PID_DIR; }; exit 0' INT TERM

echo -e "${YELLOW}Press Ctrl+C to stop all tunnels${NC}\n"

# Keep script running
wait
