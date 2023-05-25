# frozen_string_literal: true

require 'va_profile/demographics/service'

module Mobile
  module V0
    class GenderIdentityController < ApplicationController
      before_action { authorize :demographics, :access_update? }
      before_action { authorize :mpi, :queryable? }

      def edit
        options = VAProfile::Models::GenderIdentity::OPTIONS

        render json: Mobile::V0::GenderIdentityOptionsSerializer.new(@current_user.uuid, options)
      end

      def update
        gender_identity = VAProfile::Models::GenderIdentity.new gender_identity_params

        if gender_identity.valid?
          service.save_gender_identity gender_identity

          head :no_content
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
