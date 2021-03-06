local CoreFunctions = {}

function CoreFunctions:new (coreVariables)
    local object = {}

    object.Print = function(message)
        ngx.log(ngx.OK, message)
--        ngx.say(message)
    end

    object.SetupRedisKeyName = function()
        coreVariables.redis_cert_key_name       = coreVariables.server_name .. coreVariables.certSuffix
        coreVariables.redis_pem_key_name        = coreVariables.server_name .. coreVariables.pemSuffix
        coreVariables.redis_exp_key_name        = coreVariables.server_name .. coreVariables.expSuffix
        coreVariables.redis_status_key_name     = coreVariables.server_name .. coreVariables.statusSuffix
    end

    object.GetFromLua = function()
        coreVariables.currentFullChain          = coreVariables.fullChains:get(coreVariables.server_name)
        coreVariables.currentDomainKey          = coreVariables.domainKeys:get(coreVariables.server_name)
        coreVariables.currentCertExpire         = coreVariables.certsExpire:get(coreVariables.server_name)
        coreVariables.currentCertStatus         = coreVariables.certsStatus:get(coreVariables.server_name)

        if not coreVariables.currentCertStatus or coreVariables.currentCertStatus == ngx.null or coreVariables.currentCertStatus == "" then
            return false
        else
            return true
        end
    end

    object.FlushExpiredCache = function()
        --Flush Expired Keys
        coreVariables.fullChains:flush_expired()
        coreVariables.domainKeys:flush_expired()
        coreVariables.certsExpire:flush_expired()
        coreVariables.certsStatus:flush_expired()
    end

    object.FlushAllCache = function()
        --Flush All Keys
        coreVariables.fullChains:flush_all()
        coreVariables.domainKeys:flush_all()
        coreVariables.certsExpire:flush_all()
        coreVariables.certsStatus:flush_all()
    end

    object.CheckCacheStatus = function()
        local fullChainsSpace   = coreVariables.fullChains:free_space()
        local domainKeysSpace   = coreVariables.domainKeys:free_space()
        local certsExpireSpace  = coreVariables.certsExpire:free_space()
        local certsStatusSpace  = coreVariables.certsStatus:free_space()

        if fullChainsSpace < coreVariables.thresholdExpireChain or domainKeysSpace < coreVariables.thresholdExpireKey
                or certsExpireSpace < coreVariables.thresholdExpireExp or certsStatusSpace < coreVariables.thresholdExpireStatus then

            object.FlushExpiredCache()
        end

        if fullChainsSpace < coreVariables.thresholdFlushChain or domainKeysSpace < coreVariables.thresholdFlushKey
                or certsExpireSpace < coreVariables.thresholdFlushExp or certsStatusSpace < coreVariables.thresholdFlushStatus then

            object.FlushAllCache()
        end
    end

    object.SetupLuaStatusAndExpireTime = function(resPbExp, resPbStatus)
        local timestamp = os.time(os.date('*t'))

        if resPbExp and resPbExp ~= "" and resPbExp ~= ngx.null then
            coreVariables.currentCertExpire   = resPbExp
            coreVariables.currentCertExpire   = tonumber(coreVariables.currentCertExpire)

            if type(coreVariables.currentCertExpire) == 'number' then
                coreVariables.currentCertExpire = coreVariables.currentCertExpire + coreVariables.addExtraTime; -- add 20 days extra as expire time

                if timestamp then
                    coreVariables.expireDuration = coreVariables.currentCertExpire - timestamp
                else
                    coreVariables.expireDuration = coreVariables.expiresInLongTime
                end

                if coreVariables.expireDuration <= coreVariables.minimumExpTime then --needs to be more than 30s expire time
                    coreVariables.expireDuration = 1 --lowest can be 1; if you add 0 then it will act as forever in lua cache
                end
            else
                coreVariables.currentCertExpire = timestamp + coreVariables.addExtraTime --fake date
            end
        else
            coreVariables.currentCertExpire = timestamp + coreVariables.addExtraTime --fake date
        end

        --valid;  get from cert server; expire time till cert exp
        --failed; get from cert server; 6 hours expire time; if info available but failed, pending except valid
        --notfound; get from cert server; 24 hours expire time; if info not available
        --requested; this is not from cert server (local use only); expire time 5mins
        if resPbStatus and resPbStatus ~= "" and resPbStatus ~= ngx.null then
            if resPbStatus == coreVariables.valid then
                coreVariables.currentCertStatus = coreVariables.valid
                coreVariables.expireDuration = coreVariables.expiresInLongTime
                --if expire time is close to 30s then send new request
                if coreVariables.expireDuration <= coreVariables.minimumExpTime then
                    coreVariables.currentCertStatus = coreVariables.requested
                    coreVariables.expireDuration = coreVariables.expiresInShortTime
                end
            elseif resPbStatus == coreVariables.failed then
                -- if status is failed from Cert Server
                coreVariables.currentCertStatus = coreVariables.failed
                coreVariables.expireDuration = coreVariables.expiresInForFaild
            elseif resPbStatus == notfound then
                -- if status is not found from Cert Server
                coreVariables.currentCertStatus = coreVariables.notfound
                coreVariables.expireDuration = coreVariables.expiresInForNotFound
            else
                -- nothing returned from cert server, request again
                coreVariables.currentCertStatus = coreVariables.requested
                coreVariables.expireDuration = coreVariables.expiresInShortTime
            end
        else
            coreVariables.currentCertStatus = coreVariables.requested
            coreVariables.expireDuration = coreVariables.expiresInShortTime
        end
    end

    object.SetStatusRequested = function()
        coreVariables.currentCertStatus = coreVariables.requested
        coreVariables.certsStatus:set(coreVariables.server_name, coreVariables.currentCertStatus, coreVariables.expiresQuickly) --Stop request for 60s before try again
    end

    object.Decrypt = function(input)
        return coreVariables.aes_128_cbc_md5:decrypt(ngx.decode_base64(input))
    end

    object.KeyCounter = function()
        if coreVariables.fullChains:get("TotalKeys") == nil then
            coreVariables.fullChains:add("TotalKeys", 0)
        end
        coreVariables.fullChains:incr("TotalKeys", 1)

        if coreVariables.domainKeys:get("TotalKeys") == nil then
            coreVariables.domainKeys:add("TotalKeys", 0)
        end
        coreVariables.domainKeys:incr("TotalKeys", 1)

        if coreVariables.certsExpire:get("TotalKeys") == nil then
            coreVariables.certsExpire:add("TotalKeys", 0)
        end
        coreVariables.certsExpire:incr("TotalKeys", 1)

        if coreVariables.certsStatus:get("TotalKeys") == nil then
            coreVariables.certsStatus:add("TotalKeys", 0)
        end
        coreVariables.certsStatus:incr("TotalKeys", 1)
    end

    object.GetCertFromRedis = function()
        local red                   = coreVariables.redis:new()
        red:set_timeout(1000) -- 1 sec

        local ok, err               = red:connect(coreVariables.redisUrl, 6379)
        if not ok then
            -- if redis connection error the redirect to http
            object.SetStatusRequested()
            object.Print("Redis Connection ERROR!")
            --ngx.exit(500) -- do not exit
            return true
        end

        local resPbStatus, errPbStatus  = red:get(coreVariables.redis_status_key_name)
        local resPbCert, errPbCert      = red:get(coreVariables.redis_cert_key_name)
        local resPbPem, errPbPem        = red:get(coreVariables.redis_pem_key_name)
        local resPbExp, errPbExp        = red:get(coreVariables.redis_exp_key_name)

        object.CheckCacheStatus()
        object.SetupLuaStatusAndExpireTime(resPbExp, resPbStatus)

        if coreVariables.currentCertStatus == coreVariables.valid then
            if resPbCert and resPbCert ~= "" and resPbCert ~= ngx.null
                    and resPbPem and resPbPem ~= "" and resPbPem ~= ngx.null then

                coreVariables.currentFullChain                = object.Decrypt(resPbCert)
                local chainError
                coreVariables.currentFullChain, chainError    = coreVariables.ssl.cert_pem_to_der(coreVariables.currentFullChain)
                if not coreVariables.currentFullChain then
                    object.SetStatusRequested()
                    object.Print("Fullchain Convertion ERROR!")
                    return true
                end

                coreVariables.currentDomainKey                = object.Decrypt(resPbPem)
                local keyError
                coreVariables.currentDomainKey, keyError      = coreVariables.ssl.priv_key_pem_to_der(coreVariables.currentDomainKey)
                if not coreVariables.currentDomainKey then
                    object.SetStatusRequested()
                    object.Print("Key Convertion ERROR!")
                    return true
                end

                coreVariables.fullChains:set(coreVariables.server_name, coreVariables.currentFullChain, coreVariables.expireDuration)
                coreVariables.domainKeys:set(coreVariables.server_name, coreVariables.currentDomainKey, coreVariables.expireDuration)
                coreVariables.certsExpire:set(coreVariables.server_name, coreVariables.currentCertExpire, coreVariables.expireDuration)

                object.KeyCounter()
            else
                coreVariables.currentCertStatus               = coreVariables.requested
                coreVariables. expireDuration                 = coreVariables.expiresInShortTime
            end
        end

        coreVariables.certsStatus:set(coreVariables.server_name, coreVariables.currentCertStatus, coreVariables.expireDuration)

        --Must be end of the file, otherwise takes longer time
        red:set_keepalive(15000, 100)

        return false
    end

    object.RequestCachedCertificate = function()
        -- only request for cached certificate; don't order
        object.Print("Request new certificate or status from cert server")

        --https://github.com/ledgetech/lua-resty-http
        local domain = "www.firstigs.co.uk" --coreVariables.server_name
        local uri = "http://34.247.79.36/certificate/testaws.php?Domain=" .. domain
        local httpc = coreVariables.http.new()
        httpc:set_timeout(1000) --Max Wait Time 1s; 1000ms
        local res, err = httpc:request_uri(uri, {
            method = "GET",
            headers = {
                ["Content-Type"]    = "text/plain",
                ["X-API-KEY"]       = "~NWFkEWYwODM1MmZhEjA5M2FhZjdk?DFjMGQwZmRmYzc="
            },
            keepalive_timeout = 10,
            keepalive_pool = 10
        })

        if err then
            ngx.say("failed to request: ", err)
        else
            ngx.say(res.body)
        end


    end

    object.Init = function()
        local hasRedisConnectionErr = false -- default false; means no connection error

        coreVariables.expireDuration = coreVariables.expiresInLongTime --initialize expire time

        object.SetupRedisKeyName()

        if object.GetFromLua() == false then
            hasRedisConnectionErr = object.GetCertFromRedis()
        end

        -- Request cached cert before Redirect; must handle status from cert
        if coreVariables.currentCertStatus == coreVariables.requested then
            object.RequestCachedCertificate()
        end

        return hasRedisConnectionErr
    end

    return object
end

return CoreFunctions