# frozen_string_literal: true

module EVSS
  class PowerOfAttorneyVerifier
    def initialize(user)
      @user = user
      @veteran = Veteran::User.new(@user)
    end

    def verify(consumer_poa)
      if consumer_poa.present? && consumer_poa.split(',').any?
        poa_code = @veteran.power_of_attorney.try(:code)
        unless consumer_poa.split(',').include?(poa_code)
          Rails.logger.info("POA code of #{consumer_poa} not valid for veteran code #{poa_code}")
          raise Common::Exceptions::Unauthorized, detail: "Power of Attorney code doesn't match Veteran's"
        end
      end
    end

    def auth_headers
      @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
    end
  end
end
