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
      end

      def update
        write_to_vet360_and_render_transaction!(
          'permission',
          permission_params,
          http_verb: 'put'
        )
      end

      def destroy
        write_to_vet360_and_render_transaction!(
          'permission',
          permission_params,
          http_verb: 'put'
        )
      end

      private

      def permission_params
        params.permit(
          :effective_start_date,
          :id,
          :permission_type,
          :permission_value,
          :source_date,
          :transaction_id,
          :vet360_id
        )
      end
    end
  end
end
