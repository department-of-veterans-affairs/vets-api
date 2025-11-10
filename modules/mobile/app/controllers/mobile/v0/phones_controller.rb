# frozen_string_literal: true

require 'common/exceptions/validation_errors'

module Mobile
  module V0
    class PhonesController < ProfileBaseController
      before_action :log_phone_request

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

      def log_phone_request
        log_data = {
          controller: 'Mobile::V0::PhonesController',
          action: action_name,
          phone_type: params[:phone_type],
          has_id: params[:id].present?,
          phone_id: params[:id],
          transaction_id: params[:transaction_id],
          user_agent: request.user_agent,
          request_id: request.request_id,
          timestamp: Time.now.utc.iso8601,
          sis_user_uuid: current_user&.sis_uuid
        }

        Rails.logger.info('Mobile PhonesController request initiated', log_data)
      end

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
