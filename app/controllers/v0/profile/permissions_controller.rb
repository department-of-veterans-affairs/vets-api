# frozen_string_literal: true

module V0
  module Profile
    class PermissionsController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def create
        write_to_vet360_and_render_transaction!(
          'permission',
          permission_params
        )
        Rails.logger.info('PermissionsController#create request completed', sso_logging_info)
      end

      def create_or_update
        write_to_vet360_and_render_transaction!(
          'permission',
          permission_params,
          http_verb: 'update'
        )
      end

      def update
        write_to_vet360_and_render_transaction!(
          'permission',
          permission_params,
          http_verb: 'put'
        )
        Rails.logger.info('PermissionsController#update request completed', sso_logging_info)
      end

      def destroy
        write_to_vet360_and_render_transaction!(
          'permission',
          permission_params,
          http_verb: 'put'
        )
        Rails.logger.info('PermissionsController#destroy request completed', sso_logging_info)
      end

      private

      def permission_params
        params.permit(
          :id,
          :permission_type,
          :permission_value,
          :transaction_id
        )
      end
    end
  end
end
