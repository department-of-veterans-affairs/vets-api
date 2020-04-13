# frozen_string_literal: true

module ClaimsApi
  module PoaVerification
    extend ActiveSupport::Concern

    included do
      before_action :verify_power_of_attorney, if: :header_request?

      def verify_power_of_attorney
        verifier = EVSS::PowerOfAttorneyVerifier.new(target_veteran)
        verifier.verify(@current_user)
      end
    end
  end
end
