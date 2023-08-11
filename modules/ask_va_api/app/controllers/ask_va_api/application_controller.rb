# frozen_string_literal: true

module AskVAApi
  class ApplicationController < ::ApplicationController
    rescue_from DynamicsService::DynamicsServiceError, with: :no_record_error

    private

    def no_record_error(errors)
      render json: { errors: }, status: :not_found
    end

    def service_exception_handler(ex)
      context = 'An error occurred while attempting to retrieve the authenticated list of devs.'
      log_exception_to_sentry(ex, 'context' => context)
      raise exception unless ex.status == '401' || ex.status == '403'
    end
  end
end
