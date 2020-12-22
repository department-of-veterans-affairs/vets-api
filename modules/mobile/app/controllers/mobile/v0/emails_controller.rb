# frozen_string_literal: true

require 'common/exceptions/validation_errors'
require 'evss/pciu/service'

module Mobile
  module V0
    class EmailsController < ProfileBaseController
      def create
        render_transaction_to_json(
          service.save_and_await_response(resource_type: :email, params: email_params)
        )
      end

      def update
        render_transaction_to_json(
          service.save_and_await_response(resource_type: :email, params: email_params, update: true)
        )
      end

      private

      def email_params
        params.permit(
          :email_address,
          :effective_start_date,
          :id,
          :source_date,
          :transaction_id,
          :vet360_id
        )
      end
    end
  end
end
