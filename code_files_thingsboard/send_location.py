#!/usr/bin/env python3
"""
ThingsBoard Location Telemetry Sender

This script simulates sending GPS location data to ThingsBoard via HTTP.
Useful for testing the location tracking setup without a physical device.

Usage:
    python send_location.py --token YOUR_DEVICE_TOKEN --lat 34.022 --lon -118.285
    python send_location.py --token YOUR_DEVICE_TOKEN --simulate  # Simulate movement
"""

import argparse
import requests
import json
import time
import random
from datetime import datetime

# Default ThingsBoard server configuration
DEFAULT_SERVER = "http://52.42.86.26:8081"
DEFAULT_ENDPOINT = "/api/v1/{token}/telemetry"


def send_telemetry(server, token, lat, lon, batt=None, acc=None, alt=None):
    """
    Send location telemetry to ThingsBoard
    
    Args:
        server: ThingsBoard server URL
        token: Device access token
        lat: Latitude
        lon: Longitude
        batt: Battery percentage (optional)
        acc: Accuracy in meters (optional)
        alt: Altitude in meters (optional)
    
    Returns:
        Response object
    """
    url = f"{server}/api/v1/{token}/telemetry"
    
    # Build telemetry payload
    payload = {
        "_type": "location",
        "lat": lat,
        "lon": lon,
        "tst": int(time.time())
    }
    
    # Add optional fields if provided
    if batt is not None:
        payload["batt"] = batt
    if acc is not None:
        payload["acc"] = acc
    if alt is not None:
        payload["alt"] = alt
    
    headers = {
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload))
        response.raise_for_status()
        return response
    except requests.exceptions.RequestException as e:
        print(f"Error sending telemetry: {e}")
        return None


def simulate_movement(server, token, start_lat, start_lon, duration=60, interval=5):
    """
    Simulate device movement by sending location updates at regular intervals
    
    Args:
        server: ThingsBoard server URL
        token: Device access token
        start_lat: Starting latitude
        start_lon: Starting longitude
        duration: Total simulation duration in seconds
        interval: Time between updates in seconds
    """
    print(f"Starting location simulation...")
    print(f"Initial position: ({start_lat}, {start_lon})")
    print(f"Duration: {duration}s, Interval: {interval}s")
    print("-" * 50)
    
    current_lat = start_lat
    current_lon = start_lon
    battery = 100
    
    start_time = time.time()
    update_count = 0
    
    while (time.time() - start_time) < duration:
        # Simulate random movement (small increments)
        current_lat += random.uniform(-0.001, 0.001)  # ~100m
        current_lon += random.uniform(-0.001, 0.001)
        
        # Simulate battery drain
        battery = max(0, battery - random.uniform(0.1, 0.5))
        
        # Random accuracy and altitude
        accuracy = random.randint(5, 20)
        altitude = random.randint(50, 100)
        
        # Send telemetry
        response = send_telemetry(
            server, token, 
            round(current_lat, 6), 
            round(current_lon, 6),
            int(battery), 
            accuracy, 
            altitude
        )
        
        if response and response.status_code == 200:
            update_count += 1
            timestamp = datetime.now().strftime("%H:%M:%S")
            print(f"[{timestamp}] Update #{update_count}: "
                  f"Lat={current_lat:.6f}, Lon={current_lon:.6f}, "
                  f"Batt={int(battery)}%, Acc={accuracy}m")
        else:
            print(f"Failed to send update #{update_count + 1}")
        
        time.sleep(interval)
    
    print("-" * 50)
    print(f"Simulation complete. Sent {update_count} updates.")


def main():
    parser = argparse.ArgumentParser(
        description="Send location telemetry to ThingsBoard"
    )
    parser.add_argument(
        "--token", 
        required=True,
        help="ThingsBoard device access token"
    )
    parser.add_argument(
        "--server",
        default=DEFAULT_SERVER,
        help=f"ThingsBoard server URL (default: {DEFAULT_SERVER})"
    )
    parser.add_argument(
        "--lat",
        type=float,
        help="Latitude"
    )
    parser.add_argument(
        "--lon",
        type=float,
        help="Longitude"
    )
    parser.add_argument(
        "--batt",
        type=int,
        help="Battery percentage (0-100)"
    )
    parser.add_argument(
        "--acc",
        type=int,
        help="Accuracy in meters"
    )
    parser.add_argument(
        "--alt",
        type=int,
        help="Altitude in meters"
    )
    parser.add_argument(
        "--simulate",
        action="store_true",
        help="Simulate movement (requires --lat and --lon for starting position)"
    )
    parser.add_argument(
        "--duration",
        type=int,
        default=60,
        help="Simulation duration in seconds (default: 60)"
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=5,
        help="Update interval in seconds (default: 5)"
    )
    
    args = parser.parse_args()
    
    if args.simulate:
        # Simulation mode
        if args.lat is None or args.lon is None:
            parser.error("--simulate requires --lat and --lon for starting position")
        
        simulate_movement(
            args.server,
            args.token,
            args.lat,
            args.lon,
            args.duration,
            args.interval
        )
    else:
        # Single send mode
        if args.lat is None or args.lon is None:
            parser.error("--lat and --lon are required (unless using --simulate)")
        
        print(f"Sending location data to {args.server}...")
        response = send_telemetry(
            args.server,
            args.token,
            args.lat,
            args.lon,
            args.batt,
            args.acc,
            args.alt
        )
        
        if response and response.status_code == 200:
            print(f"✓ Success! Location data sent successfully.")
            print(f"  Latitude: {args.lat}")
            print(f"  Longitude: {args.lon}")
            if args.batt:
                print(f"  Battery: {args.batt}%")
            if args.acc:
                print(f"  Accuracy: {args.acc}m")
            if args.alt:
                print(f"  Altitude: {args.alt}m")
        else:
            print(f"✗ Failed to send location data")
            if response:
                print(f"  Status code: {response.status_code}")
                print(f"  Response: {response.text}")


if __name__ == "__main__":
    main()
