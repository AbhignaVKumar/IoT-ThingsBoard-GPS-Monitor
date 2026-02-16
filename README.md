# IoT Project: OwnTracks + ThingsBoard

This repository documents a hands-on IoT project using the OwnTracks mobile app and ThingsBoard Community Edition on AWS EC2.

---

## **Team Members**
- [Your Name(s)]

---

## **Project Overview**
The goal of this project is to turn a mobile phone into an IoT device that sends GPS and sensor data to a cloud platform (ThingsBoard) for real-time visualization.

We use:
- **OwnTracks App** on Android/iOS
- **ThingsBoard Community Edition** on AWS EC2
- **PostgreSQL** as the backend database
- **HTTP/MQTT** protocols for communication

---

## **Project Steps**

### Step 1: Configure OwnTracks
- Download and install [OwnTracks](https://owntracks.org/) app on your phone.
- Follow the quick setup guide: [OwnTracks Booklet](https://owntracks.org/booklet/)
- Ensure the app can send GPS/location data to a cloud endpoint.

---

### Step 2: Setup ThingsBoard on AWS
1. Launch an **Ubuntu EC2 instance** on AWS.
2. Configure the **security group** to allow all traffic (`0.0.0.0/0`) for testing.
3. SSH into the instance:
```bash
ssh -i key.pem ubuntu@<your-ec2-ip>
