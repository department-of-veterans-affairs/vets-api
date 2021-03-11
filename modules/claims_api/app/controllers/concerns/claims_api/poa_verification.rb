# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'

module ClaimsApi
  module PoaVerification
    extend ActiveSupport::Concern

    included do
      before_action :verify_power_of_attorney_using_bgs_service, if: :header_request?

      def verify_power_of_attorney_using_bgs_service
        logged_in_representative_user = @current_user
        target_veteran_to_be_verified = target_veteran
        verify_representative_and_veteran(logged_in_representative_user, target_veteran_to_be_verified)
      rescue # => e
        # Need to eventually start logging poa error logs.
        # log_message_to_sentry('PoA claims', :warning, body: e.message)
        raise ::Common::Exceptions::Unauthorized, detail: 'Cannot validate Power of Attorney'
      end

      def verify_representative_and_veteran(logged_in_representative_user, target_veteran_to_be_verified)
        verifying_bgs_service = BGS::PowerOfAttorneyVerifier.new(target_veteran_to_be_verified)
        verifying_bgs_service.verify(logged_in_representative_user)
        true
      end
    end
  end
end
