# frozen_string_literal: true

module Eps
  class RedisClient
    extend Forwardable

    attr_reader :settings

    def_delegators :settings, :redis_token_expiry

    def initialize
      @settings = Settings.check_in.travel_reimbursement_api_v2
    end

    def token
      Rails.cache.read(
        'token',
        namespace: 'vaos-eps-cache'
      )
    end

    def save_token(token:)
      Rails.cache.write(
        'token',
        token,
        namespace: 'vaos-eps-cache',
        expires_in: redis_token_expiry
      )
    end

    def provider_id(referral_number:)
      fetch_attribute(referral_number:, attribute: :provider_id)
    end

    def appointment_type_id(referral_number:)
      fetch_attribute(referral_number:, attribute: :appointment_type_id)
    end

    def end_date(referral_number:)
      fetch_attribute(referral_number:, attribute: :end_date)
    end

    def save(referral_number:, referral:)
      Rails.cache.write(
        "vaos_eps_referral_identifier_#{referral_number}",
        referral,
        namespace: 'vaos-eps-cache',
        expires_in: redis_token_expiry
      )
    end

    def fetch_attribute(referral_number:, attribute:)
      identifiers = referral_identifiers(referral_number:)
      return nil if identifiers.nil?

      parsed_identifiers = Oj.load(identifiers).with_indifferent_access
      parsed_identifiers.dig(:data, :attributes, attribute)
    end

    private

    def referral_identifiers(referral_number:)
      @referral_identifiers ||= Hash.new do |h, key|
        h[key] = Rails.cache.read(
          "vaos_eps_referral_identifier_#{key}",
          namespace: 'vaos-eps-cache'
        )
      end
      @referral_identifiers[referral_number]
    end
  end
end
