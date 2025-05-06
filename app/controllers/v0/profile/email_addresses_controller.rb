# frozen_string_literal: true

module V0
  module Profile
    class EmailAddressesController < ApplicationController
      include Vet360::Writeable
      service_tag 'profile'

      before_action { authorize :va_profile, :access_to_v2? }
      after_action :invalidate_cache

      def create
        write_to_vet360_and_render_transaction!(
          'email',
          email_address_params
        )
        Rails.logger.warn('EmailAddressesController#create request completed', sso_logging_info)
      end

      def create_or_update
        write_to_vet360_and_render_transaction!(
          'email',
          email_address_params,
          http_verb: 'update'
        )
      end

      def update
        write_to_vet360_and_render_transaction!(
          'email',
          email_address_params,
          http_verb: 'put'
        )
        Rails.logger.warn('EmailAddressesController#update request completed', sso_logging_info)
      end

      def destroy
        write_to_vet360_and_render_transaction!(
          'email',
          add_effective_end_date(email_address_params),
          http_verb: 'put'
        )
        Rails.logger.warn('EmailAddressesController#destroy request completed', sso_logging_info)
      end

      private

      def email_address_params
        params.permit(
          :email_address,
          :id,
          :transaction_id
        )
      end
    end
  end
end
