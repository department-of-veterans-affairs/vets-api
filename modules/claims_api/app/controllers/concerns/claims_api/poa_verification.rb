# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'

module ClaimsApi
  module PoaVerification
    extend ActiveSupport::Concern

    included do
      before_action :verify_power_of_attorney, if: :header_request?

      def verify_power_of_attorney
        verifier = BGS::PowerOfAttorneyVerifier.new(target_veteran)
        verifier.verify(@current_user)
      rescue => e
        log_message_to_sentry('PoA Error in claims',
                              :warning,
                              body: e.message)
        render json: { errors: [{ status: 401, detail: "Can't establish Power of Attorney validation." }] },
               status: :unauthorized
      end
    end
  end
end
