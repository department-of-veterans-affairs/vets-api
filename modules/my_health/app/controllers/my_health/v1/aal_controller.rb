# frozen_string_literal: true

module MyHealth
  module V1
    class AALController < ApplicationController
      include MyHealth::AALClientConcerns
      service_tag 'mhv-aal'

      before_action :authorize_aal
      before_action :authenticate_aal_client!

      def create
        once_per_session = ActiveModel::Type::Boolean.new.cast(params[:once_per_session])

        create_aal!(aal_params, once_per_session:)
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

      def authorize_aal
        if current_user&.mhv_correlation_id.blank?
          raise Common::Exceptions::Forbidden,
                detail: 'You do not have access to the AAL service'
        end
      end
    end
  end
end
