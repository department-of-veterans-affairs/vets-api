# frozen_string_literal: true

require 'common/client/session'

module AAL
  class MRClientSession < Common::Client::Session
    redis_store REDIS_CONFIG[:aal_mr_store][:namespace]
    redis_ttl REDIS_CONFIG[:aal_mr_store][:each_ttl]
    redis_key :user_id
  end

  class RXClientSession < Common::Client::Session
    redis_store REDIS_CONFIG[:aal_rx_store][:namespace]
    redis_ttl REDIS_CONFIG[:aal_rx_store][:each_ttl]
    redis_key :user_id
  end

  class SMClientSession < Common::Client::Session
    redis_store REDIS_CONFIG[:aal_sm_store][:namespace]
    redis_ttl REDIS_CONFIG[:aal_sm_store][:each_ttl]
    redis_key :user_id
  end
end
