# MIPI D-PHY Protocol 
### MIPI D-PHY is a physical layer (PHY) standard developed by the MIPI Alliance, widely used in mobile and embedded systems for high-speed serial communication — primarily between application processors and peripherals like cameras (CSI-2) and displays (DSI).

## Core Architecture
### D-PHY uses a lane-based differential signaling architecture with two distinct operating modes:
### - High-Speed (HS) Mode — For bulk data transfer at high bandwidth, using low-voltage differential signaling (LVDS-like).
### - Low-Power (LP) Mode — For control signals and lane management, using single-ended signaling at lower speeds.

## Each lane consists of a differential pair (D+ / D-), and a typical link includes:
### - 1 Clock Lane — Provides the reference clock for HS transfers.
### - 1 to 4 Data Lanes — Carry the actual payload (some versions support up to 8).
