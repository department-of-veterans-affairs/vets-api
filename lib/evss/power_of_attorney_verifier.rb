# frozen_string_literal: true

module EVSS
  class PowerOfAttorneyVerifier
    def initialize(user)
      @user = user
      @veteran = Veteran::User.new(@user)
    end

    def verify(user)
      representitive = Veteran::Service::Representative.for_user(first_name: user.first_name, last_name: user.last_name)
      if representitive.present?
        veteran_poa_code = @veteran.power_of_attorney.try(:code)
        unless matches(@veteran, representitive)
          Rails.logger.info("POA code of #{representitive.poa} not valid for veteran code #{veteran_poa_code}")
          raise Common::Exceptions::Unauthorized, detail: "Power of Attorney code doesn't match Veteran's"
        end
      else
        raise Common::Exceptions::Unauthorized, detail: 'VSO Representitive Not Found'
      end
    end

    def matches(veteran, representitive); end

    def auth_headers
      @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
    end
  end
end
