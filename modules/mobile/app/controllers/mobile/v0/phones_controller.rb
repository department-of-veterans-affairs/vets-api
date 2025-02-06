# frozen_string_literal: true

require 'common/exceptions/validation_errors'

module Mobile
  module V0
    class PhonesController < ProfileBaseController
      def create
        render_transaction_to_json(
          service.save_and_await_response(resource_type: :telephone, params: phone_params)
        )
      end

      def update
        render_transaction_to_json(
          service.save_and_await_response(resource_type: :telephone, params: phone_params, update: true)
        )
      end

      def destroy
        delete_params = phone_params.to_h.merge(effective_end_date: Time.now.utc.iso8601)
        render_transaction_to_json(
          service.save_and_await_response(resource_type: :telephone, params: delete_params, update: true)
        )
      end

      private

      def phone_params
        params.permit(
          :id,
          :area_code,
          :country_code,
          :extension,
          :phone_number,
          :phone_type,
          :is_international,
          :is_text_permitted,
          :is_textable,
          :is_tty,
          :is_voicemailable,
          :transaction_id
        )
      end
    end
  end
end
