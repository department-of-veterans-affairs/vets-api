# frozen_string_literal: true

require 'common/exceptions/validation_errors'
require 'evss/pciu/service'

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

      private

      def phone_params
        params.permit(
          :id,
          :area_code,
          :country_code,
          :extension,
          :phone_number,
          :phone_type
        )
      end
    end
  end
end
