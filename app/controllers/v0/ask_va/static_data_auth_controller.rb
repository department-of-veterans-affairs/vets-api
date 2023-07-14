# frozen_string_literal: true

require 'date'

module V0
  module AskVA
    class StaticDataAuthController < ApplicationController
      def index
        data = {
          Ruchi: { 'data-info': 'ruchi.shah@thoughtworks.com' },
          Eddie: { 'data-info': 'eddie.otero@oddball.io' },
          Jacob: { 'data-info': 'jacob@docme360.com' },
          Joe: { 'data-info': 'joe.hall@thoughtworks.com' },
          Khoa: { 'data-info': 'khoa.nguyen@oddball.io' }
        }
        render json: data, status: :ok
      rescue => e
        service_exception_handler(e)
      end

      private

      def service_exception_handler(exception)
        context = 'An error occurred while attempting to retrieve the authenticated list of devs.'
        log_exception_to_sentry(exception, 'context' => context)

        case exception.status.code
        when 401, 403
          # in the real implementation, we'll differentiate between 401 and 403
          render json: { errors: exception }, status: :unauthorized
        else
          raise exception
        end
      end
    end
  end
end
