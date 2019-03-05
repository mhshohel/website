local redis                 = require "resty.redis"
local shdict                = require "resty.core.shdict" --require for capacity, flush
local aes                   = require "resty.aes"
local ssl                   = require "ngx.ssl"
local strlen                = string.len

local key                   = os.getenv("ENC_ENV_KEY")
local iv                    = os.getenv("ENC_ENV_IV")
local aes_128_cbc_md5       = assert(aes:new(key, nil, aes.cipher(128,"cbc"), {iv=iv}))

local server_name
local redis_cert_key_name
local redis_pem_key_name
local redis_exp_key_name
local redis_status_key_name
local redisUrl              = "172.16.238.1"

local certSuffix            = "-pbcert"     --FullChain
local pemSuffix             = "-pbpem"      --Key
local expSuffix             = "-pbexp"
local statusSuffix          = "-pbstatus"
local appSuffix             = "-pbapp"

local currentFullChain
local currentDomainKey
local currentCertExpire
local currentCertStatus

local fullChains            = ngx.shared.fullchains     --Keep Certificate FullChain; DER Verision
local domainKeys            = ngx.shared.domainkeys     --Keep Domain Key; DER Verision
local certsExpire           = ngx.shared.certsexpire    --Keep Certificate Nex Update Date
local certsStatus           = ngx.shared.certsstatus    --Keep Certificate Validitiy Status

local expiresQuickly        = 60        -- 60  -- 1 min
local expiresInShortTime    = 300       -- 300  -- 5 mins
local expiresInForNotFound  = 86400     -- 86400  -- 24 hours; for not found status
local expiresInForFaild     = 21600     -- 21600  -- 6 hours; for failed status
local expiresInLongTime     = 5184000   -- 5184000 -- default 60 days; can be changed depends on NextUpdateDate
local addExtraTime          = 1728000   -- 1728000 20 days extra time as expire time from next update time
local minimumExpTime        = 30        -- 30 Expiration time should be more than 30s
local expireDuration        = 1         -- set new expired time; this is used to set expire time; should be fix before update cache

local thresholdExpireChain  = 20971520  --Flush cert and key expired cache if reach to 20MB = 20971520 bytes
local thresholdExpireKey    = 20971520  --Flush cert and key expired cache if reach to 20MB = 20971520 bytes
local thresholdExpireExp    = 2097152   --Flush expire and status expired cache if reach to 2MB = 2097152 bytes
local thresholdExpireStatus = 2097152   --Flush expire and status expired cache if reach to 2MB = 2097152 bytes

local thresholdFlushChain   = 10485760  --Flush cert and key all cache if reach to 10MB = 10485760 bytes
local thresholdFlushKey     = 10485760  --Flush cert and key all cache if reach to 10MB = 10485760 bytes
local thresholdFlushExp     = 1048576   --Flush expire and status all cache if reach to 1MB = 1048576 bytes
local thresholdFlushStatus  = 1048576   --Flush expire and status all cache if reach to 1MB = 1048576 bytes

local valid                 = "valid"       -- valid;  get from cert server; expire time till cert exp
local failed                = "failed"      --get from cert server; 6 hours expire time; if info available but failed, pending except valid
local notfound              = "notfound"    --get from cert server; 24 hours expire time; if info not available
local requested             = "requested"   --this is not from cert server (local use only); expire time 5mins

local function FlushExpiredCache()
    --Flush Expired Keys
    fullChains:flush_expired()
    domainKeys:flush_expired()
    certsExpire:flush_expired()
    certsStatus:flush_expired()
end

local function FlushAllCache()
    --Flush All Keys
    fullChains:flush_all()
    domainKeys:flush_all()
    certsExpire:flush_all()
    certsStatus:flush_all()
end

local function CheckCacheStatus()
    local fullChainsSpace   = fullChains:free_space()
    local domainKeysSpace   = domainKeys:free_space()
    local certsExpireSpace  = certsExpire:free_space()
    local certsStatusSpace  = certsStatus:free_space()

    if fullChainsSpace < thresholdExpireChain or domainKeysSpace < thresholdExpireKey
        or certsExpireSpace < thresholdExpireExp or certsStatusSpace < thresholdExpireStatus then

        FlushExpiredCache()
    end

    if fullChainsSpace < thresholdFlushChain or domainKeysSpace < thresholdFlushKey
        or certsExpireSpace < thresholdFlushExp or certsStatusSpace < thresholdFlushStatus then

        FlushAllCache()
    end
end

local function CheckSNIName()
    server_name = ngx.var.host

    --Remove me
    -----------------------------------------------------------------------------------------------------
    server_name = string.gsub(ngx.var.request_uri, "/ssltest/", "")
    -----------------------------------------------------------------------------------------------------

    if not server_name then
        local sni, err      = ssl.server_name()
        if not err then
            server_name = sni
        else
            ngx.exit(ngx.ERR, "Server name (SNI) not found...")   -- Exit only on ERROR
        end
    end
end

local function SetupRedisKeyName()
    redis_cert_key_name     = server_name .. certSuffix
    redis_pem_key_name      = server_name .. pemSuffix
    redis_exp_key_name      = server_name .. expSuffix
    redis_status_key_name   = server_name .. statusSuffix
end

local function KeyCounter()
    if fullChains:get("TotalKeys") == nil then
        fullChains:add("TotalKeys", 0)
    end
    fullChains:incr("TotalKeys", 1)

    if domainKeys:get("TotalKeys") == nil then
        domainKeys:add("TotalKeys", 0)
    end
    domainKeys:incr("TotalKeys", 1)

    if certsExpire:get("TotalKeys") == nil then
        certsExpire:add("TotalKeys", 0)
    end
    certsExpire:incr("TotalKeys", 1)

    if certsStatus:get("TotalKeys") == nil then
        certsStatus:add("TotalKeys", 0)
    end
    certsStatus:incr("TotalKeys", 1)
end

local function Decrypt(input)
    return aes_128_cbc_md5:decrypt(ngx.decode_base64(input))
end

local function RequestCachedCertificate()
    -- only request for cached certificate; don't order
    ngx.say("Request new certificate or status from cert server")
end

local function HTTPRedirect80()
    ngx.say(ngx.var.server_port)
    ngx.say("Redirect to HTTP")

    --    if port ~= 80 then
    --        ngx.say("Redirecting to HTTP site...")
    --    end
end

local function HTTPSRedirect443()
    ngx.say(ngx.var.server_port)
    ngx.say("Redirect to HTTPS or HTTP depending on PORT")

    --    if port ~= 443 then
    --        ngx.say("Redirecting to HTTP site...")
    --    else
    --        HTTPRedirect80()
    --    end
end

local function SetupLuaStatusAndExpireTime(resPbExp, resPbStatus)
    local timestamp = os.time(os.date('*t'))

    if resPbExp and resPbExp ~= "" and resPbExp ~= ngx.null then
        currentCertExpire   = resPbExp
        currentCertExpire   = tonumber(currentCertExpire)

        if type(currentCertExpire) == 'number' then
            currentCertExpire = currentCertExpire + addExtraTime; -- add 20 days extra as expire time

            if timestamp then
                expireDuration = currentCertExpire - timestamp
            else
                expireDuration = expiresInLongTime
            end

            if expireDuration <= minimumExpTime then --needs to be more than 30s expire time
                expireDuration = 1 --lowest can be 1; if you add 0 then it will act as forever in lua cache
            end
        else
            currentCertExpire = timestamp + addExtraTime --fake date
        end
    else
        currentCertExpire = timestamp + addExtraTime --fake date
    end

    --valid;  get from cert server; expire time till cert exp
    --failed; get from cert server; 6 hours expire time; if info available but failed, pending except valid
    --notfound; get from cert server; 24 hours expire time; if info not available
    --requested; this is not from cert server (local use only); expire time 5mins
    if resPbStatus and resPbStatus ~= "" and resPbStatus ~= ngx.null then
        if resPbStatus == valid then
            currentCertStatus = valid
            expireDuration = expiresInLongTime
            --if expire time is close to 30s then send new request
            if expireDuration <= minimumExpTime then
                currentCertStatus = requested
                expireDuration = expiresInShortTime
            end
        elseif resPbStatus == failed then
            -- if status is failed from Cert Server
            currentCertStatus = failed
            expireDuration = expiresInForFaild
        elseif resPbStatus == notfound then
            -- if status is not found from Cert Server
            currentCertStatus = notfound
            expireDuration = expiresInForNotFound
        else
            -- nothing returned from cert server, request again
            currentCertStatus = requested
            expireDuration = expiresInShortTime
        end
    else
        currentCertStatus = requested
        expireDuration = expiresInShortTime
    end
end

local function GetCertFromRedis()
    ngx.say("Get From REDIS")

    -- We must have status from Cert Server; Later Cert server should update Redis status
    local red                   = redis:new()
    red:set_timeout(1000) -- 1 sec

    local ok, err               = red:connect(redisUrl, 6379)
    if not ok then
        -- if redis connection error the redirect to http
        currentCertStatus = requested
        certsStatus:set(server_name, currentCertStatus, expiresQuickly) --Stop request for 60s before try again
        --ngx.exit(500) -- do not exit
        return true
    end

    local resPbStatus, errPbStatus  = red:get(redis_status_key_name)
    local resPbCert, errPbCert      = red:get(redis_cert_key_name)
    local resPbPem, errPbPem        = red:get(redis_pem_key_name)
    local resPbExp, errPbExp        = red:get(redis_exp_key_name)

    CheckCacheStatus()
    SetupLuaStatusAndExpireTime(resPbExp, resPbStatus)

    if currentCertStatus == valid then
        if resPbCert and resPbCert ~= "" and resPbCert ~= ngx.null
            and resPbPem and resPbPem ~= "" and resPbPem ~= ngx.null then

            currentFullChain                = Decrypt(resPbCert)

            local chainError
            currentFullChain, chainError    = ssl.cert_pem_to_der(currentFullChain)
            if not currentFullChain then
                currentCertStatus = requested
                certsStatus:set(server_name, currentCertStatus, expiresQuickly)
                return true
            end

            currentDomainKey                = Decrypt(resPbPem)
            local keyError
            currentDomainKey, keyError      = ssl.priv_key_pem_to_der(currentDomainKey)
            if not currentDomainKey then
                currentCertStatus = requested
                certsStatus:set(server_name, currentCertStatus, expiresQuickly)
                return true
            end

            fullChains:set(server_name, currentFullChain, expireDuration)
            domainKeys:set(server_name, currentDomainKey, expireDuration)
            certsExpire:set(server_name, currentCertExpire, expireDuration)

            KeyCounter()
        else
            currentCertStatus               = requested
            expireDuration                  = expiresInShortTime
        end
    end

    certsStatus:set(server_name, currentCertStatus, expireDuration)

    --Must be end of the file, otherwise takes longer time
    red:set_keepalive(15000, 100)

    return false
end

local function GetFromLua()
    currentFullChain            = fullChains:get(server_name)
    currentDomainKey            = domainKeys:get(server_name)
    currentCertExpire           = certsExpire:get(server_name)
    currentCertStatus           = certsStatus:get(server_name)

    if not currentCertStatus or currentCertStatus == ngx.null or currentCertStatus == "" then
        return false
    else
        ngx.say("Got From LUA")
        return true
    end
end

local function HandleYourSite()
    local hasRedisConnectionErr = false -- default false
    expireDuration = expiresInLongTime --initialize expire time

    CheckSNIName()
    SetupRedisKeyName()

    ngx.say(server_name)

    if GetFromLua() == false then
        hasRedisConnectionErr = GetCertFromRedis()
    end

    -- Request before Redirect
    if currentCertStatus == requested then
        RequestCachedCertificate()
    end

    if hasRedisConnectionErr == false then
        if currentCertStatus == valid then
            ngx.say("Valid; Status: " .. currentCertStatus)
            HTTPSRedirect443()
        else
            ngx.say("Not Valid; Status: " .. currentCertStatus)
            HTTPRedirect80()
        end

        ngx.say("......................")
        ngx.say(expireDuration / 86400 .. " days")
        ngx.say("......................")
    else
        ngx.say("Not Valid (Redis Connection ERROR); Status: " .. currentCertStatus)
        HTTPRedirect80()
    end
end

local clock = os.clock
local start = clock()

HandleYourSite()

local endtiem = (clock() - start)
ngx.say("----------------------")
ngx.say("Total Time In Seconds: " .. endtiem)
ngx.say("Total Time In Readable Seconds: " .. endtiem * 1000)
ngx.say("----------------------")


--ngx.say('HI')
--ngx.say(ngx.var.remote_addr)
--ngx.say(ngx.var.server_port)


--return ngx.redirect("http://www.google.com")
--echo "$server_port:$request_uri"



-- If cert found in redis
-- if cert not found in redis then request to cert server
-- after request if cert not found create
-- if found check status
-- if not pending then try again



--ngx.STDERR
--ngx.EMERG
--ngx.ALERT
--ngx.CRIT
--ngx.ERR
--ngx.WARN
--ngx.NOTICE
--ngx.INFO
--ngx.DEBUG

--ngx.log(ngx.STDERR, requestUri)
--ngx.log(ngx.ERR, requestUri)

--local red = redis:new()
--red:set_timeout(300) -- 1 sec = 1000
----
--local ok, err = red:connect("172.16.238.1", 6379)
--if not ok then
--    ngx.say("failed to connect: ", err)
--    return
--end
--local res, err = red:get(requestUri)
--if not res or res == ngx.null then
----    check backup before redirect to http
--    return ngx.exit(404)
--else
--    local clock = os.clock
--    local start = clock()
--
--
----        ngx.say(t.FullChain)
----        ngx.say(chain_der)
--
--        local endtiem = (clock() - start)
--        ngx.say(endtiem)
--        ngx.say(endtiem * 1000)
--    else
--        ngx.say('Owned By PB')
--    end
--
--end

