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
      @settings = Settings.check_in.travel_reimbursement_api_v2
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

    # v1 service VEIS token cache (separate from v0 to avoid conflicts)
    def v1_veis_token
      Rails.cache.read(
        'token',
        namespace: 'check-in-btsss-cache-v1'
      )
    end

    def save_v1_veis_token(token:)
      Rails.cache.write(
        'token',
        token,
        namespace: 'check-in-btsss-cache-v1',
        expires_in: redis_token_expiry
      )
    end

    # v4 system token (BTSSS) stored under a non-PHI cache key provided by caller
    def v4_token(cache_key:)
      Rails.cache.read(
        cache_key,
        namespace: 'check-in-travel-pay-cache'
      )
    end

    def save_v4_token(cache_key:, token:)
      Rails.cache.write(
        cache_key,
        token,
        namespace: 'check-in-travel-pay-cache',
        expires_in: redis_token_expiry
      )
    end

    def icn(uuid:)
      fetch_attribute(uuid:, attribute: :icn)
    end

    def mobile_phone(uuid:)
      fetch_attribute(uuid:, attribute: :mobilePhone)
    end

    def patient_cell_phone(uuid:)
      fetch_attribute(uuid:, attribute: :patientCellPhone)
    end

    def station_number(uuid:)
      fetch_attribute(uuid:, attribute: :stationNo)
    end

    def facility_type(uuid:)
      fetch_attribute(uuid:, attribute: :facilityType)
    end

    # Returns the last four digits of the claim number associated with the appointment
    # @param uuid [String] The appointment UUID
    # @return [String, nil] The last four digits of the claim number or nil if not found
    def claim_number_last_four(uuid:)
      fetch_attribute(uuid:, attribute: :claimNumber)
    end

    def fetch_attribute(uuid:, attribute:)
      identifiers = appointment_identifiers(uuid:)
      return nil if identifiers.nil?

      parsed_identifiers = Oj.load(identifiers).with_indifferent_access
      parsed_identifiers.dig(:data, :attributes, attribute)
    end

    private

    def appointment_identifiers(uuid:)
      @appointment_identifiers ||= Hash.new do |h, key|
        h[key] = Rails.cache.read(
          "check_in_lorota_v2_appointment_identifiers_#{key}",
          namespace: 'check-in-lorota-v2-cache'
        )
      end
      @appointment_identifiers[uuid]
    end
  end
end
