# frozen_string_literal: true

require 'common/client/session'

module Mobile
  module V0
    module Messaging
      class ClientSession < Common::Client::Session
        redis_store REDIS_CONFIG[:sm_store_mobile][:namespace]
        redis_ttl 900
        redis_key :user_id
      end
    end
  end
end
