# frozen_string_literal: true

require 'common/client/session'

module BBInternal
  class ClientSession < Common::Client::Session
    # attribute :icn, String
    attribute :patient_id, String

    redis_store REDIS_CONFIG[:bb_internal_store][:namespace]
    redis_ttl 3600
    redis_key :user_id
  end
end
