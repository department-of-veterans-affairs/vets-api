# frozen_string_literal: true

require 'common/exceptions/validation_errors'

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

      def destroy
        delete_params = email_params.to_h.merge(effective_end_date: Time.now.utc.iso8601)
        render_transaction_to_json(
          service.save_and_await_response(resource_type: :email, params: delete_params, update: true)
        )
      end

      private

      def email_params
        params.permit(
          :confirmation_date,
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
