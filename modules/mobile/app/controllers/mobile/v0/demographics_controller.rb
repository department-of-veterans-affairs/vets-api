# frozen_string_literal: true

require 'va_profile/demographics/service'

module Mobile
  module V0
    class DemographicsController < ApplicationController
      before_action { authorize :demographics, :access_update? }
      before_action { authorize :mpi, :queryable? }

      def index
        response = service.get_demographics
        raise_error(response) if response.status != 200
        render json: Mobile::V0::DemographicsSerializer.new(@current_user.icn, response)
      end

      private

      def raise_error(response)
        case response.status
        when 400
          raise Common::Exceptions::BadRequest
        when 404
          raise Common::Exceptions::RecordNotFound, @current_user.icn
        end

        raise Common::Exceptions::BackendServiceException
      end

      def service
        VAProfile::Demographics::Service.new @current_user
      end
    end
  end
end
