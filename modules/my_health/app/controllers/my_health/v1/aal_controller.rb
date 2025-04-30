# frozen_string_literal: true

module MyHealth
  module V1
    class AALController < ApplicationController
      include MyHealth::AALClientConcerns
      service_tag 'mhv-aal'

      # skip_before_action :authenticate

      def create
        attributes = aal_params.except(:product)
        resource = aal_client.create_aal(attributes)
        render json: resource.to_json
      end

      protected

      def aal_params
        params.permit(
          :activity_type,
          :action,
          :completion_time,
          :performer_type,
          :detail_value,
          :status,
          :product
        )
      end

      def product
        params[:product]&.to_sym
      end
    end
  end
end
