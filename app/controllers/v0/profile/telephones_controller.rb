# frozen_string_literal: true

module V0
  module Profile
    class TelephonesController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def create
        write_to_vet360_and_render_transaction!(
          'telephone',
          telephone_params
        )
        Rails.logger.info('TelephonesController#create request completed', sso_logging_info)
      end

      def update
        write_to_vet360_and_render_transaction!(
          'telephone',
          telephone_params,
          http_verb: 'put'
        )
        Rails.logger.info('TelephonesController#update request completed', sso_logging_info)
      end

      def destroy
        write_to_vet360_and_render_transaction!(
          'telephone',
          add_effective_end_date(telephone_params),
          http_verb: 'put'
        )
        Rails.logger.info('TelephonesController#destroy request completed', sso_logging_info)
      end

      private

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
