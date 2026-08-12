services:
  homeassistant:
    container_name: homeassistant
    image: "ghcr.io/home-assistant/home-assistant:stable"
    volumes:
      - ./homeassistant/config:/config
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
      - /dev/serial/by-path:/dev/serial/by-path
    restart: unless-stopped
    privileged: true
    network_mode: host
    # cap_add a ete retire d'ici

  mosquitto:
    image: eclipse-mosquitto:latest
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "1883:1883"
    volumes:
      - /opt/mosquitto/config:/mosquitto/config
      - /opt/mosquitto/data:/mosquitto/data
      - /opt/mosquitto/log:/mosquitto/log

  matter-server:
    image: ghcr.io/home-assistant-libs/python-matter-server:stable
    container_name: matter-server
    restart: unless-stopped
    network_mode: host
    privileged: true
    cap_add:
      - NET_ADMIN
      - NET_RAW
    security_opt:
      - apparmor=unconfined
    volumes:
      - /ServeurImmich/matter/data:/data
      - /run/dbus:/run/dbus:ro
    command: ["--storage-path", "/data", "--paa-root-cert-dir", "/data/credentials", "--primary-interface", "enp4s0"]
  openthread:
    image: openthread/otbr:latest
    container_name: openthread
    restart: unless-stopped
    network_mode: host
    privileged: true
    cap_add:
      - NET_ADMIN
      - NET_RAW
    environment:
      - WEB_GUI=0
      - REST_API=1
      - FIREWALL=0
      - INFRA_IF_NAME=enp4s0
      - BACKBONE_INTERFACE=enp4s0
    volumes:
      - /ServeurImmich/openthread_data:/var/lib/thread
    devices:
      - source: /dev/serial/by-path/pci-0000:00:1a.0-usb-0:1.1:1.0-port0
        target: /dev/ttyThread
    command: ["--radio-url", "spinel+hdlc+uart:///dev/ttyThread?uart-baudrate=230400&uart-flow-control"]