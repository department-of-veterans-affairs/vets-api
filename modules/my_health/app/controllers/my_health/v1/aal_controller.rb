# frozen_string_literal: true

module MyHealth
  module V1
    class AALController < ApplicationController
      include MyHealth::AALClientConcerns
      service_tag 'mhv-aal'

      def create
        once_per_session = ActiveModel::Type::Boolean.new.cast(params[:oncePerSession])

        create_aal(aal_params, once_per_session:)
        head :no_content
      end

      protected

      def aal_params
        params.require(:aal).permit(
          :activity_type,
          :action,
          :completion_time,
          :performer_type,
          :detail_value,
          :status
        )
      end
    end
  end
end
