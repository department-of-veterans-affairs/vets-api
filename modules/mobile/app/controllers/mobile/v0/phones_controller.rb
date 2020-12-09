# frozen_string_literal: true

require 'common/exceptions/validation_errors'
require 'evss/pciu/service'

module Mobile
  module V0
    class PhonesController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache
      
      def create
        transaction = service.save_and_await_response(resource_type: 'telephone', params: phone_params)
        render json: transaction, serializer: AsyncTransaction::BaseSerializer
      end

      def update
        transaction = service.save_and_await_response(resource_type: 'telephone', params: phone_params, update: true)
        render json: transaction, serializer: AsyncTransaction::BaseSerializer
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
