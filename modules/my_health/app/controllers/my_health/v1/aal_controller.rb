# frozen_string_literal: true

module MyHealth
  module V1
    class AALController < ApplicationController
      include MyHealth::AALClientConcerns
      service_tag 'mhv-aal'

      def create
        attributes = aal_params.except(:product)
        aal_client.create_aal(attributes)
        head :no_content
      end

      protected

      def aal_params
        aal = params.require(:aal).permit(
          :activity_type,
          :action,
          :completion_time,
          :performer_type,
          :detail_value,
          :status
        )
        aal[:product] = params[:product]
        aal
      end
    end
  end
end
