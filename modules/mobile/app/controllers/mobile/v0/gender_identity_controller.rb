# frozen_string_literal: true

require 'va_profile/demographics/service'

# NOTE: Endpoints remain for backwards compatibility with mobile clients. They should be removed in the future.

module Mobile
  module V0
    class GenderIdentityController < ApplicationController
      before_action(only: :update) { authorize :demographics, :access_update? }
      before_action { authorize :mpi, :queryable? }

      def edit
        options = {}

        render json: Mobile::V0::GenderIdentityOptionsSerializer.new(@current_user.uuid, options)
      end

      def update
        render json: {
          errors: [
            {
              detail: 'This field no longer exists and cannot be updated',
              source: 'Mobile::V0::GenderIdentityController#update',
              code: '410',
              status: '410',
              title: 'Gone'
            }
          ]
        }, status: :gone
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
