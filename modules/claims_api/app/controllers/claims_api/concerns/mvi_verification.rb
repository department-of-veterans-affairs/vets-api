# frozen_string_literal: true

module ClaimsApi
  module MviVerification
    extend ActiveSupport::Concern

    included do
      before_action :verify_mvi

      def verify_mvi
        unless target_veteran.mvi_record?
          render json: { errors: [{ detail: 'Not found' }] },
                 status: :not_found
        end
      end
    end
  end
end
