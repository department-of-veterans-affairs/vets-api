# frozen_string_literal: true

module TravelPay
  class ClaimsService
    def initialize(auth_manager)
      @auth_manager = auth_manager
    end

    def get_claims(params = {})
      @auth_manager.authorize => { veis_token:, btsss_token: }
      faraday_response = client.get_claims(veis_token, btsss_token)
      raw_claims = faraday_response.body['data'].deep_dup

      claims = filter_by_date(params['appt_datetime'], raw_claims)

      {
        data: claims.map do |sc|
          sc['claimStatus'] = sc['claimStatus'].underscore.titleize
          sc
        end
      }
    end

    def get_claim_by_id(claim_id)
      # ensure claim ID is the right format, allowing any version
      uuid_all_version_format = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[89ABCD][0-9A-F]{3}-[0-9A-F]{12}$/i

      unless uuid_all_version_format.match?(claim_id)
        raise ArgumentError, message: "Expected claim id to be a valid UUID, got #{claim_id}."
      end

      @auth_manager.authorize => { veis_token:, btsss_token: }
      claims_response = client.get_claims(veis_token, btsss_token)

      claims = claims_response.body['data']

      claim = claims.find { |c| c['id'] == claim_id }

      if claim
        claim['claimStatus'] = claim['claimStatus'].underscore.titleize
        claim
      end
    end

    def create_new_claim(params = {})
      # ensure appt ID is the right format, allowing any version
      uuid_all_version_format = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[89ABCD][0-9A-F]{3}-[0-9A-F]{12}$/i

      unless params['btsss_appt_id']
        raise ArgumentError,
              message: 'You must provide a BTSSS appointment ID to create a claim.'
      end

      unless uuid_all_version_format.match?(params['btsss_appt_id'])
        raise ArgumentError,
              message: "Expected BTSSS appointment id to be a valid UUID, got #{params['btsss_appt_id']}."
      end

      @auth_manager.authorize => { veis_token:, btsss_token: }
      new_claim_response = client.create_claim(veis_token, btsss_token, params)

      new_claim_response.body
    end

    private

    def filter_by_date(date_string, claims)
      if date_string.present?
        parsed_appt_date = Date.parse(date_string)

        claims.filter do |claim|
          !claim['appointmentDateTime'].nil? &&
            parsed_appt_date == Date.parse(claim['appointmentDateTime'])
        end
      else
        claims
      end
    rescue Date::Error => e
      Rails.logger.debug(message: "#{e}. Not filtering claims by date (given: #{date_string}).")
      claims
    end

    def client
      TravelPay::ClaimsClient.new
    end
  end
end
