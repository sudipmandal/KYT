# KYT utilities

This repository contains assorted personal utilities and configuration files.

## Minecraft server block list

`minecraft-block-list.txt` is a hosts-format list of publicly advertised Minecraft server domains. Every row uses:

```text
0.0.0.0 server.example.com
```

The list is normalized, sorted, and deduplicated. Numeric IP addresses are intentionally excluded because this file tracks domain addresses. It is assembled from publicly discoverable listings, so it is broad but cannot guarantee every public Minecraft server on the internet.

Current discovery sources:

- [Minecraft Java Servers public API](https://minecraft-java-servers.com/api)
- [MinecraftServers.cz public API](https://minecraftservers.cz/docs/api)
- [TopG Minecraft server directory](https://topg.org/Minecraft)
- [Servers-Minecraft directory](https://servers-minecraft.com/)
- [Minecraft Server List](https://minecraft-server-list.com/)
- [Minecraft-Servers.co directory](https://minecraft-servers.co/)

A daily Hermes job checks these sources and commits newly advertised domains without removing existing entries.

<!-- minecraft-domain-count -->
Current unique domain count: **15,204**.
