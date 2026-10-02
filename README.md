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

## Role-playing game block list

`rpg-block-list.txt` is a hosts-format list of official public domains for video games classified in the role-playing genre hierarchy. The updater queries Wikidata for video-game items with official website property `P856`, normalizes the website hostnames, and excludes generic storefront, social-network, wiki, archive, and CDN platforms that would block unrelated content.

The list retains previously discovered domains, is sorted and deduplicated, and is updated daily directly on `master`. It is broad but cannot guarantee every RPG domain on the internet because public metadata changes continuously.

Primary discovery sources:

- [Wikidata Query Service](https://query.wikidata.org/), using the RPG genre hierarchy and official website property documented by [Wikidata WikiProject Video games](https://www.wikidata.org/wiki/Wikidata:WikiProject_Video_games/Properties)
- Daily web search for RPG, MMORPG, and browser role-playing websites, with relevance checks and exclusions for generic search, social, wiki, news, and storefront domains

<!-- rpg-domain-count -->
Current unique RPG domain count: **4,086**.

<!-- minecraft-domain-count -->
Current unique domain count: **15,302**.
