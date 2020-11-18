# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'

module ClaimsApi
  module PoaVerification
    extend ActiveSupport::Concern

    included do
      before_action :verify_power_of_attorney, if: :header_request?

      def verify_power_of_attorney
        logged_in_representative_user = @current_user
        target_veteran_to_be_verified = BGS::PowerOfAttorneyVerifier.new(target_veteran)
        target_veteran_to_be_verified.verify(logged_in_representative_user)
        true
      rescue => e
        log_message_to_sentry('PoA claims', :warning, body: e.message)
        raise Common::Exceptions::Unauthorized, detail: 'Cannot validate Power of Attorney'
      end
    end
  end
end
