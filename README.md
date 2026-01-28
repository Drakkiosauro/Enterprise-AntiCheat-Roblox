Enterprise Anti-Cheat Roblox.

Overview
Enterprise Anti-Cheat is a robust, server-side focused security solution for Roblox environments. It is designed to mitigate common exploits such as speed hacks, teleportation, fly hacks, and remote event spoofing through advanced logic and client-server synchronization.

Technical Features
Token-Based Handshake The system generates a unique GUID (Globally Unique Identifier) for each player session. This token must be passed with every remote event call. Requests without a valid token are flagged as Remote Spoofing attempts, resulting in an immediate ban.

Dynamic Remote Security The communication bridge between client and server uses dynamically named RemoteEvents. This obfuscation technique prevents automated scripts and basic executors from easily locating and firing security-related events.

Predictive Movement Verification Instead of simple distance checks, the system calculates the maximum possible distance a player can travel based on:

Humanoid WalkSpeed

Delta Time (dt)

Network Latency (Ping Compensation)

Active Position Correction (Rubberbanding) When a violation is detected but does not yet meet the ban threshold, the system forcefully resets the player's HumanoidRootPart to their last known valid position, effectively nullifying the exploit in real-time.

Environment Integrity Checks The client-side component performs periodic scans for common exploit signatures, such as unauthorized changes to the game's metatable or the presence of global functions typically injected by script executors.

Configuration
The system is highly customizable via the SETTINGS table:

WALK_SPEED_LIMIT: The base speed allowed.

TELEPORT_THRESHOLD: Maximum distance allowed between frames before a reset occurs.

VIOLATIONS_TO_BAN: Strictness level for permanent automated actions.

Disclaimer
This software is provided for educational purposes in the field of defensive security. It is intended to demonstrate how to protect game integrity against common exploitation methods within the Luau environment.
