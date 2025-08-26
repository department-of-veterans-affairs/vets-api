module TravelPay
  module V0
    class ComplexClaimsController < ApplicationController
      def create
        verify_feature_flag_enabled!

      end

      private

      def verify_feature_flag_enabled!
        return if Flipper.enabled?(:travel_pay_enable_complex_claims, @current_user)

        message = 'Travel Pay create complex claim unavailable per feature toggle'
        Rails.logger.error(message:)
        raise Common::Exceptions::ServiceUnavailable, message:
      end
    end
  end
end