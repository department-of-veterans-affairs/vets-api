# frozen_string_literal: true

require 'va_profile/demographics/service'

module Mobile
  module V0
    class PreferredNamesController < ApplicationController
      before_action { authorize :demographics, :access_update? }
      before_action { authorize :mpi, :queryable? }

      def update
        preferred_name = VAProfile::Models::PreferredName.new preferred_name_params

        if preferred_name.valid?
          service.save_preferred_name preferred_name

          head :no_content
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
