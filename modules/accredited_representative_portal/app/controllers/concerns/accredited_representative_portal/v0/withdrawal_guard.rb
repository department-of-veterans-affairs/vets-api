# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    module WithdrawalGuard
      extend ActiveSupport::Concern

      included do
        private

        def render_404_if_withdrawn!(poa_request)
          if poa_request.resolution&.resolving.is_a?(
            PowerOfAttorneyRequestWithdrawal
          )
            render json: { errors: ['Record not found'] }, status: :not_found
          end
        end
      end
    end
  end
end
