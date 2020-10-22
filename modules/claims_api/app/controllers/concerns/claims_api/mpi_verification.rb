# frozen_string_literal: true

module ClaimsApi
  module MPIVerification
    extend ActiveSupport::Concern

    included do
      before_action :verify_mvi

      def verify_mvi
        unless target_veteran.mvi_record?
          log_message_to_sentry('MVIError in claims',
                                :warning,
                                body: target_veteran.mvi&.response&.error&.inspect)
          render json: { errors: [{ detail: 'MVI user not found' }] },
                 status: :not_found
        end
      end
    end
  end
end
