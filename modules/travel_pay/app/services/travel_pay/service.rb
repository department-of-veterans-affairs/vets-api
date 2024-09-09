# frozen_string_literal: true

module TravelPay
  class Service
    def get_claims(current_user, params = {})
      faraday_response = client.get_claims(current_user)
      claims = faraday_response.body['data'].deep_dup

      begin
        if params['appt_datetime'].present?
          parsed_appt_date = Date.parse(params['appt_datetime'])
          claims = filter_by_date(parsed_appt_date, claims)
        end
      rescue Date::Error => de
        Rails.logger.debug(message: "#{de}. Not filtering claims by date (given: #{params['appt_datetime']}).")
      end

      {
        data: claims.map do |sc|
          sc['claimStatus'] = sc['claimStatus'].underscore.titleize
          sc
        end
      }
    end

    private

    def filter_by_date(date, claims)
      claims.filter do |claim|
        !claim['appointmentDateTime'].nil? && 
          date == Date.parse(claim['appointmentDateTime'])
      end
    end

    def client
      TravelPay::Client.new
    end
  end
end
