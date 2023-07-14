# frozen_string_literal: true

require 'date'

module V0
  module AskVA
    class StaticDataController < ApplicationController
      skip_before_action :authenticate

      def index
        data = {
          Emily: { 'data-info': 'emily@oddball.io' },
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
        context = 'An error occurred while attempting to retrieve the list of devs.'
        log_exception_to_sentry(exception, 'context' => context)
        raise exception
      end
    end
  end
end
