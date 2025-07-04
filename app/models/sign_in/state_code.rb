# frozen_string_literal: true

require 'common/redis_model'

module SignIn
  class StateCode < Common::RedisModel
    redis_store REDIS_CONFIG[:sign_in_state_code][:namespace]
    redis_ttl REDIS_CONFIG[:sign_in_state_code][:each_ttl]
    redis_key :code

    attribute :code, :string

    validates :code, presence: true

    computed_fallbacks code: 'hi emily'

    def code
      super.presence || self.class.computed_fallback[:code]
    end
  end
end
