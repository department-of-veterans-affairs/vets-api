# frozen_string_literal: true

module V0
  module Profile
    class TelephonesController < ApplicationController
      include Vet360::Writeable
      service_tag 'profile'

      before_action { authorize :va_profile, :access_to_v2? }
      before_action :log_telephone_request
      after_action :invalidate_cache

      def create
        write_to_vet360_and_render_transaction!(
          'telephone',
          telephone_params
        )
        Rails.logger.warn('TelephonesController#create request completed', sso_logging_info)
      end

      def create_or_update
        write_to_vet360_and_render_transaction!(
          'telephone',
          telephone_params,
          http_verb: 'update'
        )
        Rails.logger.warn('TelephonesController#create_or_update request completed', sso_logging_info)
      end

      def update
        write_to_vet360_and_render_transaction!(
          'telephone',
          telephone_params,
          http_verb: 'put'
        )
        Rails.logger.warn('TelephonesController#update request completed', sso_logging_info)
      end

      def destroy
        write_to_vet360_and_render_transaction!(
          'telephone',
          add_effective_end_date(telephone_params),
          http_verb: 'put'
        )
        Rails.logger.warn('TelephonesController#destroy request completed', sso_logging_info)
      end

      private

      def log_telephone_request
        log_data = {
          action: action_name,
          phone_type: params[:phone_type],
          has_id: params[:id].present?,
          phone_id: params[:id],
          transaction_id: params[:transaction_id],
          user_agent: request.user_agent,
          request_id: request.request_id,
          timestamp: Time.now.utc.iso8601
        }.merge(sso_logging_info)

        Rails.logger.info('TelephonesController request initiated', log_data)
      end

      def telephone_params
        params.permit(
          :area_code,
          :country_code,
          :extension,
          :id,
          :is_international,
          :is_textable,
          :is_text_permitted,
          :is_tty,
          :is_voicemailable,
          :phone_number,
          :phone_type,
          :transaction_id
        )
      end
    end
  end
end
