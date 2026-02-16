# Multi-Device Live Location Tracking on ThingsBoard

## Overview

This project demonstrates a real-time, multi-phone location tracking solution using **ThingsBoard Community Edition (CE)**. Each mobile device sends GPS data via HTTP using the **OwnTracks** app to a ThingsBoard telemetry endpoint. An OpenStreetMap widget on a ThingsBoard dashboard visualizes the live positions of all devices.

### Key Features

- ✅ Multi-device live tracking
- ✅ Real-time map updates (3–5s refresh)
- ✅ Optional telemetry fields: battery (`batt`), accuracy (`acc`), altitude (`alt`)

### Platform & Tools

| Component | Technology |
|-----------|------------|
| **Server** | Ubuntu EC2 instance (AWS) |
| **ThingsBoard** | CE 3.6.x (DEB install) |
| **Database** | PostgreSQL 16 |
| **Mobile App** | OwnTracks (iOS/Android) |
| **Server Endpoint** | http://52.42.86.26:8081 (optionally via Nginx on port 80) |

---

## Architecture

### Data Flow

```
Phone (OwnTracks, HTTP) 
      ↓
ThingsBoard HTTP Telemetry API /api/v1/<TOKEN>/telemetry
      ↓
Timeseries KV Storage (lat, lon, etc.)
      ↓
Dashboard (OpenStreetMap widget, Latest values)
      ↓
Live Map Visualization
```

### Components

- ThingsBoard CE service with PostgreSQL backend
- OwnTracks app publishing HTTP JSON payloads
- ThingsBoard dashboard with OpenStreetMap widget
- Entity alias referencing multiple devices

---

## Environment Setup

### Prerequisites

1. **PostgreSQL 16** installed and started

2. **ThingsBoard CE** DEB installed and configured in `/etc/thingsboard/conf/thingsboard.conf`:
   - **DB**: JDBC URL pointing to `thingsboard` Postgres DB
   - **Queue**: `TB_QUEUE_TYPE=in-memory` (demo/lab)
   - **Server port**: `SERVER_PORT=8081`
   - **Java**: Set system Java to OpenJDK 11 (compatible with TB 3.6)

3. **Initialize service** with demo data:
   ```bash
   sudo /usr/share/thingsboard/bin/install/install.sh --loadDemo
   ```

4. **Start ThingsBoard**:
   ```bash
   sudo service thingsboard start
   journalctl -u thingsboard -f  # Verify "Tomcat started on 8081"
   ```

5. **Optional**: Nginx reverse proxy to expose port 80 externally

### Notes

- ⚠️ Switched to Java 11 due to JDK17 module encapsulation errors
- ⚠️ Ensure EC2 security groups allow inbound HTTP/HTTPS access for testing

---

## Device Provisioning & Telemetry

### 1. Create Devices

Create a device in ThingsBoard per phone (e.g., `Alice-iPhone`, `Bob-Pixel`) and copy its **access token**.

### 2. Test Telemetry with cURL

```bash
curl -X POST http://52.42.86.26:8081/api/v1/<TOKEN>/telemetry \
-H 'Content-Type: application/json' \
-d '{"_type":"location","lat":34.022,"lon":-118.285,"batt":87,"acc":10,"alt":73,"tst":1730000000}'
```

### 3. OwnTracks Configuration (HTTP mode)

#### iOS Settings
- **Location**: Always
- **Precise**: ON
- **Background refresh**: ON

#### Android Settings
- **Location**: Always
- Disable battery optimizations
- Set shorter intervals

#### App Configuration
- **URL**: `http://52.42.86.26:8081/api/v1/<TOKEN>/telemetry`

### 4. Verify Telemetry

Navigate to **Device → Latest telemetry** to confirm data is being received.

---

## Dashboard (OpenStreetMap)

### Setup Steps

1. **Create a dashboard** (e.g., `Team_Map`) in ThingsBoard

2. **Add Entity Alias** (e.g., `PhonesAlias`) including all devices

3. **Add widget** → Maps → OpenStreetMap

4. **Configure Widget Data**:
   - **Entity alias**: `PhonesAlias`
   - **Latitude key**: `lat`
   - **Longitude key**: `lon`
   - **Additional keys**: `batt`, `acc`, `alt` (optional)

5. **Popup/Tooltip** (optional):
   - **Title**: `${deviceName}`
   - **Body**: `Battery: ${batt}% | Acc: ${acc} m | Alt: ${alt} m`

6. **Time Settings**:
   - Set to **Realtime**
   - Window: **Last 1 hour**
   - Update interval: **3–5s**

7. **Save dashboard**; markers update as phones move

---

## Design Decisions & Rationale

| Decision | Rationale |
|----------|-----------|
| **TB CE + Postgres** | Minimal infra, easy time-series storage, rich dashboard support |
| **HTTP + OwnTracks** | Simplifies setup, avoids MQTT broker, easy to debug |
| **Key schema** | `lat`/`lon` mandatory; optional `batt`/`acc`/`alt` enriches visualization |
| **Java 11** | Stable with TB 3.6, avoids JDK17 module issues |
| **Nginx (optional)** | Exposes port 80 to bypass firewall restrictions |

---

## Testing & Validation

- ✅ **Confirm service health**: `journalctl` logs
- ✅ **Test ingress**: `curl` sends test points; verify telemetry updates
- ✅ **Realtime map**: markers update every 3–5s
- ✅ **Multi-device**: multiple phones tracked simultaneously
- ✅ **Resilience**: brief network gaps do not impact data integrity

---

## Challenges & Solutions

| Issue | Solution |
|-------|----------|
| Port 8080 blocked externally | Switched TB to 8081 / added Nginx 80→8081 |
| JDK17 module errors | Downgraded to Java 11 |
| 404 on telemetry | Fixed path `/api/v1/<TOKEN>/telemetry` |
| Markers not moving | Set dashboard to Realtime, confirm `lat`/`lon` keys |

---

## Security & Operational Notes

- 🔐 Device tokens are write-scoped; **keep private**
- 🔐 Restrict inbound rules after demo to authorized IPs
- 🔐 Use **TLS (HTTPS)** for production deployments
- 📊 **Data retention**: configure TTL/partitions for production; demo uses default

---

## References

- [OwnTracks](https://owntracks.org/)
- [ThingsBoard Documentation](https://thingsboard.io/docs/)
- [AWS EC2 Linux Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstances.html)

---

