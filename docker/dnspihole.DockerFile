services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    cap_add:
      - NET_ADMIN
    networks:
      lan_physique:
        ipv4_address: 192.168.1.53
    environment:
      TZ: 'Europe/Paris'
      WEBPASSWORD: 'admin'
    dns:
      - 127.0.0.1
      - 1.1.1.1
    volumes:
      - './pihole/etc-pihole:/etc/pihole'
      - './pihole/etc-dnsmasq.d:/etc/dnsmasq.d'
    restart: unless-stopped

networks:
  lan_physique:
    name: lan_physique
    driver: macvlan
    driver_opts:
      parent: enp4s0
    ipam:
      config:
        - subnet: 192.168.1.0/24
          gateway: 192.168.1.254