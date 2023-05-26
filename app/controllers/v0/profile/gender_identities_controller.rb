# frozen_string_literal: true

require 'va_profile/demographics/service'

module V0
  module Profile
    class GenderIdentitiesController < ApplicationController
      before_action { authorize :demographics, :access? }
      before_action { authorize :mpi, :queryable? }

      def update
        gender_identity = VAProfile::Models::GenderIdentity.new gender_identity_params

        if gender_identity.valid?
          response = service.save_gender_identity gender_identity

          Rails.logger.info('GenderIdentitiesController#create request completed', sso_logging_info)

          render json: response, serializer: GenderIdentitySerializer
        else
          raise Common::Exceptions::ValidationErrors, gender_identity
        end
      end

      private

      def service
        VAProfile::Demographics::Service.new @current_user
      end

      def gender_identity_params
        params.permit(:code)
      end
    end
  end
end
