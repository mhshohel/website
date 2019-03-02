-- Notes:
-- First Check Challenge in Lua then Redis
-- Reason to keep in Lua is in worst case if challenge link used by someone for request
-- Always clean expire keys on request from Redis

local redis                 = require "resty.redis"
local shdict                = require "resty.core.shdict" --requore for capacity, flush

local acmeLocalUrl          = "/.well%-known/acme%-challenge/"   -- "-" is special, need to add % before it to remove using gsub
local requestUriKey         = string.gsub(ngx.var.request_uri, acmeLocalUrl, "")

local acmeChallenge         = ngx.shared.acmechallenge
local expiresInShortTime    = 300 --300  -- 5 mins if challenge not found
local expiresInLongTime     = 21600 --21600 -- 6 hours if challenge found
local thresholdExpire       = 3145728 --Flush expired cache if reach to 3MB = 3145728 bytes
local thresholdFlush        = 1048576 --Flush all cache if reach to 1MB = 1048576 bytes

local challenge             = "none"

local function FlushExpiredCache(freeSpace)
    --Flush Expired Keys
    if freeSpace < thresholdExpire then
        acmeChallenge:flush_expired()
    end
end

local function FlushAllCache(freeSpace)
    --Flush All Keys
    if freeSpace < thresholdFlush then
        acmeChallenge:flush_all()
    end
end

local function CheckCacheStatus()
    local freeSpace = acmeChallenge:free_space()
    FlushExpiredCache(freeSpace)
    FlushAllCache(freeSpace)
end

local function GetChallengeFromRedis()
    local redisUrl              = "172.16.238.1"

    local red                   = redis:new()
    red:set_timeout(1000) -- 1 sec

    local ok, err               = red:connect(redisUrl, 6379)
    if not ok then
        ngx.exit(500)   -- Exit only on ERROR
    end

    local res, err              = red:get(requestUriKey)
    if not res or res == ngx.null then
        -- Do not send any message, otherwise it will always set status 200
        -- bgx.exit stops the connection pool, so we don't exit
        res                     = "none"
        acmeChallenge:set(requestUriKey, res, expiresInShortTime);
    else
        acmeChallenge:set(requestUriKey, res, expiresInLongTime);
    end

    if acmeChallenge:get("TotalKeys") == nil then
        acmeChallenge:add("TotalKeys", 0);
    end

    acmeChallenge:incr("TotalKeys", 1)

    challenge = res

    --Must be end of the file, otherwise takes longer time
    red:set_keepalive(10000, 20) --20 connections is fine for acme

    CheckCacheStatus()
end

local function GetFromLua()
    challenge       = acmeChallenge:get(requestUriKey)

    if not challenge then
        return false
    else
        return true
    end
end

local function HandleAcmeChallenges()
    if GetFromLua() == false then
        GetChallengeFromRedis()
    end

    ngx.say(challenge)
end

HandleAcmeChallenges()