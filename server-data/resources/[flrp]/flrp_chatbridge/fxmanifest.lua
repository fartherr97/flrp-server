fx_version 'cerulean'
game 'gta5'

author 'FLRP'
description 'FLRP chat bridge: streams in-game chat to a Discord channel (webhook) and renders Discord replies in the chatbox as [Discord] Name'
version '1.0.0'
lua54 'yes'

-- Outbound: flrp_chat calls exports.flrp_chatbridge:Relay(src, name, message, tag)
-- for every global line; lines are batched and POSTed to the webhook in
-- flrp_chat_bridge_webhook (secrets.cfg).
-- Inbound: flrp_api's POST /chat/discord calls exports.flrp_chatbridge:FromDiscord(name, message).
shared_script 'config.lua'
server_script 'server.lua'
