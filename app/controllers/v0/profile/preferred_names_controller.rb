# frozen_string_literal: true

require 'va_profile/demographics/service'

module V0
  module Profile
    class PreferredNamesController < ApplicationController
      before_action { authorize :demographics, :access? }
      before_action { authorize :mpi, :queryable? }

      def update
        preferred_name = VAProfile::Models::PreferredName.new preferred_name_params

        if preferred_name.valid?
          response = service.save_preferred_name preferred_name
          Rails.logger.info('PreferredNamesController#create request completed', sso_logging_info)

          render json: response, serializer: PreferredNameSerializer
        else
          raise Common::Exceptions::ValidationErrors, preferred_name
        end
      end

      private

      def service
        VAProfile::Demographics::Service.new @current_user
      end

      def preferred_name_params
        params.permit(:text)
      end
    end
  end
end
