extends Control
## Desktop root: always the background scene once logged in (per the design
## brief). The header and footer manage themselves (desktop_header.gd,
## desktop_footer.gd) — this script owns nothing yet, but is the future home
## for spawning/managing windows (encrypted chat, phone, SMS, mail, file
## explorer, ...) into WindowLayer, the empty area reserved between them.
