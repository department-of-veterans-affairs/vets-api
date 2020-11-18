# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'

module ClaimsApi
  module PoaVerification
    extend ActiveSupport::Concern

    included do
      before_action :verify_power_of_attorney, if: :header_request?

      def verify_power_of_attorney
        BGS::PowerOfAttorneyVerifier.new(target_veteran).verify(@current_user)
      rescue => e
        log_message_to_sentry('PoA Error in claims',
                              :warning,
                              body: e.message)
        raise Common::Exceptions::Unauthorized, detail: 'Cannot at this time establish Power of Attorney validation'
      end
    end
  end
end
