# frozen_string_literal: true

module ClaimsApi
  module MviVerification
    extend ActiveSupport::Concern

    included do
      before_action :verify_mpi

      def verify_mpi
        unless target_veteran.mpi_record?
          log_message_to_sentry('MVIError in claims',
                                :warning,
                                body: target_veteran.mpi&.response&.error&.inspect)
          render json: { errors: [{ detail: 'MVI user not found' }] },
                 status: :not_found
        end
      end
    end
  end
end
