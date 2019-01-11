# frozen_string_literal: true

module EVSS
  class PowerOfAttorneyVerifier
    def initialize(user)
      @user = user
      @use_mock = Settings.evss.power_of_attorney_verifier || false
      @veteran = Veteran.new(@user)
    end

    def verify(header)
      if header.present? && header.split(',').any?
        unless header.split(',').include?(@veteran.power_of_attorney.try(:code))
          raise Common::Exceptions::Unauthorized, detail: "Power of Attorney code doesn't match Veteran's"
        end
      end
    end

    def auth_headers
      @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
    end
  end
end
