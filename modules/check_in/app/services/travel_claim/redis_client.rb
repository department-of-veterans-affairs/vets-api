# frozen_string_literal: true

module TravelClaim
  class RedisClient
    extend Forwardable

    attr_reader :settings

    def_delegators :settings, :redis_token_expiry

    def self.build
      new
    end

    def initialize
      @settings = Settings.check_in.travel_reimbursement_api
    end

    def get
      Rails.cache.read(
        'token',
        namespace: 'check-in-btsss-cache'
      )
    end

    def save(token:)
      Rails.cache.write(
        'token',
        token,
        namespace: 'check-in-btsss-cache',
        expires_in: redis_token_expiry
      )
    end
  end
end
