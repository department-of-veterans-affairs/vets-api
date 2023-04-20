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

    def token
      Rails.cache.read(
        'token',
        namespace: 'check-in-btsss-cache'
      )
    end

    def save_token(token:)
      Rails.cache.write(
        'token',
        token,
        namespace: 'check-in-btsss-cache',
        expires_in: redis_token_expiry
      )
    end

    def icn(uuid:)
      appointment_identifiers = Rails.cache.read(
        "check_in_lorota_v2_appointment_identifiers_#{uuid}",
        namespace: 'check-in-lorota-v2-cache'
      )
      return nil if appointment_identifiers.nil?

      Oj.load(appointment_identifiers).with_indifferent_access.dig(:data, :attributes, :icn)
    end

    def mobile_phone(uuid:)
      appointment_identifiers = Rails.cache.read(
        "check_in_lorota_v2_appointment_identifiers_#{uuid}",
        namespace: 'check-in-lorota-v2-cache'
      )
      return nil if appointment_identifiers.nil?

      Oj.load(appointment_identifiers).with_indifferent_access.dig(:data, :attributes, :mobilePhone)
    end
  end
end
