# frozen_string_literal: true

module Mobile
  module V0
    class DependentsController < ApplicationController
      def show
        dependents = dependent_service.get_dependents
        render json: dependents, serializer: DependentsSerializer
      rescue => e
        log_exception_to_sentry(e)
        raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)
      end

      def dependent_service
        @dependent_service ||= BGS::DependentService.new(current_user)
      end
    end
  end
end