# frozen_string_literal: true

module ClaimsApi
  module PoaVerification
    extend ActiveSupport::Concern

    included do
      before_action :verify_power_of_attorney, if: :poa_request?

      def verify_power_of_attorney
        verifier = EVSS::PowerOfAttorneyVerifier.new(target_veteran)
        verifier.verify(@current_user)
      end

      def poa_request?
        # if any of the required headers are present we should attempt to use headers
        headers_to_check = %w[HTTP_X_VA_SSN HTTP_X_VA_Consumer-Username HTTP_X_VA_Birth_Date]
        (request.headers.to_h.keys & headers_to_check).length.positive?
      end
    end
  end
end
