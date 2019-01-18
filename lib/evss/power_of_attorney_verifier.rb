# frozen_string_literal: true

module EVSS
  class PowerOfAttorneyVerifier
    def initialize(user)
      @user = user
      @veteran = Veteran.new(@user)
    end

    def verify(custom_consumer_ids)
      if custom_consumer_ids.present? && custom_consumer_ids.split(',').any?
        poa_code = @veteran.power_of_attorney.try(:code)
        unless custom_consumer_ids.split(',').include?(poa_code)
          Rails.logger.info("POA code of #{custom_consumer_ids} not valid for veteran code #{poa_code}")
          raise Common::Exceptions::Unauthorized, detail: "Power of Attorney code doesn't match Veteran's"
        end
      end
    end

    def auth_headers
      @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
    end
  end
end
