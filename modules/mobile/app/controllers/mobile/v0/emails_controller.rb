# frozen_string_literal: true

require 'common/exceptions/validation_errors'
require 'evss/pciu/service'

module Mobile
  module V0
    class EmailsController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def create
        transaction = service.save_and_await_response(resource_type: 'email', params: email_params)
        render json: transaction, serializer: AsyncTransaction::BaseSerializer
      end
      
      def update
        transaction = service.save_and_await_response(resource_type: 'email', params: email_params, update: true)
        render json: transaction, serializer: AsyncTransaction::BaseSerializer
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
