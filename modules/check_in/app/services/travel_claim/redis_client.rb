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
      if Flipper.enabled?('check_in_experience_travel_claim_redis_client_refactor')
        return fetch_attribute(uuid:, attribute: :icn)
      end

      return nil if appointment_identifiers(uuid:).nil?

      Oj.load(appointment_identifiers(uuid:)).with_indifferent_access.dig(:data, :attributes, :icn)
    end

    def mobile_phone(uuid:)
      if Flipper.enabled?('check_in_experience_travel_claim_redis_client_refactor')
        return fetch_attribute(uuid:, attribute: :mobilePhone)
      end

      return nil if appointment_identifiers(uuid:).nil?

      Oj.load(appointment_identifiers(uuid:)).with_indifferent_access.dig(:data, :attributes, :mobilePhone)
    end

    def patient_cell_phone(uuid:)
      if Flipper.enabled?('check_in_experience_travel_claim_redis_client_refactor')
        return fetch_attribute(uuid:, attribute: :patientCellPhone)
      end

      return nil if appointment_identifiers(uuid:).nil?

      Oj.load(appointment_identifiers(uuid:)).with_indifferent_access.dig(:data, :attributes, :patientCellPhone)
    end

    def station_number(uuid:)
      if Flipper.enabled?('check_in_experience_travel_claim_redis_client_refactor')
        return fetch_attribute(uuid:, attribute: :stationNo)
      end

      return nil if appointment_identifiers(uuid:).nil?

      Oj.load(appointment_identifiers(uuid:)).with_indifferent_access.dig(:data, :attributes, :stationNo)
    end

    def facility_type(uuid:)
      if Flipper.enabled?('check_in_experience_travel_claim_redis_client_refactor')
        return fetch_attribute(uuid:, attribute: :facilityType)
      end

      return nil if appointment_identifiers(uuid:).nil?

      Oj.load(appointment_identifiers(uuid:)).with_indifferent_access.dig(:data, :attributes, :facilityType)
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
