local CoreVariables = {}

function CoreVariables:new ()
    local object = {}

    object.redis                    = require "resty.redis"
    object.base                     = require "resty.core.base"
    object.shdict                   = require "resty.core.shdict" --require for capacity, flush
    object.aes                      = require "resty.aes"
    object.ssl                      = require "ngx.ssl"
    object.strlen                   = string.len
    object.http                     = require "/var/www/html/website/nginx-lua/lib/resty/http"

    object.key                      = os.getenv("ENC_ENV_KEY")
    object.iv                       = os.getenv("ENC_ENV_IV")
    object.aes_128_cbc_md5          = assert(object.aes:new(object.key, nil, object.aes.cipher(128,"cbc"), {iv=object.iv}))

    object.server_name              = ""
    object.redis_cert_key_name      = ""
    object.redis_pem_key_name       = ""
    object.redis_exp_key_name       = ""
    object.redis_status_key_name    = ""
    object.redisUrl                 = "172.16.238.1"

    object.certSuffix               = "-pbcert"         --FullChain
    object.pemSuffix                = "-pbpem"          --Key
    object.expSuffix                = "-pbexp"
    object.statusSuffix             = "-pbstatus"
    object.appSuffix                = "-pbapp"

    object.currentFullChain         = ""
    object.currentDomainKey         = ""
    object.currentCertExpire        = ""
    object.currentCertStatus        = ""

    object.fullChains               = ngx.shared.fullchains     --Keep Certificate FullChain; DER Verision
    object.domainKeys               = ngx.shared.domainkeys     --Keep Domain Key; DER Verision
    object.certsExpire              = ngx.shared.certsexpire    --Keep Certificate Nex Update Date
    object.certsStatus              = ngx.shared.certsstatus    --Keep Certificate Validitiy Status

    object.expiresQuickly           = 60        -- 60  -- 1 min
    object.expiresInShortTime       = 300       -- 300  -- 5 mins
    object.expiresInForNotFound     = 86400     -- 86400  -- 24 hours; for not found status
    object.expiresInForFaild        = 21600     -- 21600  -- 6 hours; for failed status
    object.expiresInLongTime        = 5184000   -- 5184000 -- default 60 days; can be changed depends on NextUpdateDate
    object.addExtraTime             = 1728000   -- 1728000 20 days extra time as expire time from next update time
    object.minimumExpTime           = 30        -- 30 Expiration time should be more than 30s
    object.expireDuration           = 1         -- set new expired time; this is used to set expire time; should be fix before update cache

    object.thresholdExpireChain     = 20971520  --Flush cert and key expired cache if reach to 20MB = 20971520 bytes
    object.thresholdExpireKey       = 20971520  --Flush cert and key expired cache if reach to 20MB = 20971520 bytes
    object.thresholdExpireExp       = 2097152   --Flush expire and status expired cache if reach to 2MB = 2097152 bytes
    object.thresholdExpireStatus    = 2097152   --Flush expire and status expired cache if reach to 2MB = 2097152 bytes

    object.thresholdFlushChain      = 10485760  --Flush cert and key all cache if reach to 10MB = 10485760 bytes
    object.thresholdFlushKey        = 10485760  --Flush cert and key all cache if reach to 10MB = 10485760 bytes
    object.thresholdFlushExp        = 1048576   --Flush expire and status all cache if reach to 1MB = 1048576 bytes
    object.thresholdFlushStatus     = 1048576   --Flush expire and status all cache if reach to 1MB = 1048576 bytes

    object.valid                    = "valid"       --valid;  get from cert server; expire time till cert exp
    object.failed                   = "failed"      --get from cert server; 6 hours expire time; if info available but failed, pending except valid
    object.notfound                 = "notfound"    --get from cert server; 24 hours expire time; if info not available
    object.requested                = "requested"   --this is not from cert server (local use only); expire time 5mins

    return object
end

return CoreVariables