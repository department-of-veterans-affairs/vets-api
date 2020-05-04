# frozen_string_literal: true

module EVSS
  class PowerOfAttorneyVerifier
    def initialize(user)
      @user = user
      @veteran = Veteran::User.new(@user)
    end

    def current_poa
      @current_poa ||= @veteran.power_of_attorney.try(:code)
    end

    def verify(user)
      rep = Veteran::Service::Representative.for_user(first_name: user.first_name, last_name: user.last_name)
      if rep.present?
        veteran_poa_code = current_poa
        unless matches(veteran_poa_code, rep)
          Rails.logger.info("POA code of #{rep.poa_codes.join(', ')} not valid for veteran code #{veteran_poa_code}")
          raise Common::Exceptions::Unauthorized, detail: "Power of Attorney code doesn't match Veteran's"
        end
      else
        raise Common::Exceptions::Unauthorized, detail: 'VSO Representative Not Found'
      end
    end

    def matches(veteran_poa_code, representative)
      representative.poa_codes.include?(veteran_poa_code)
    end

    def auth_headers
      @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
    end
  end
end
