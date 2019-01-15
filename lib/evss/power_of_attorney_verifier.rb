# frozen_string_literal: true

module EVSS
  class PowerOfAttorneyVerifier
    def initialize(user)
      @user = user
      @veteran = Veteran.new(@user)
    end

    def verify(custom_consumer_ids)
      if custom_consumer_ids.present? && custom_consumer_ids.split(',').any?
        unless custom_consumer_ids.split(',').include?(@veteran.power_of_attorney.try(:code))
          raise Common::Exceptions::Unauthorized, detail: "Power of Attorney code doesn't match Veteran's"
        end
      end
    end

    def auth_headers
      @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
    end
  end
end
