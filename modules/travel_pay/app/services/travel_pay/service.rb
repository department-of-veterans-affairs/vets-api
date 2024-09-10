# frozen_string_literal: true

module TravelPay
  class Service
    def get_claims(current_user, params = {})
      faraday_response = client.get_claims(current_user)
      raw_claims = faraday_response.body['data'].deep_dup

      claims = filter_by_date(params['appt_datetime'], raw_claims)

      {
        data: claims.map do |sc|
          sc['claimStatus'] = sc['claimStatus'].underscore.titleize
          sc
        end
      }
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
      TravelPay::Client.new
    end
  end
end
