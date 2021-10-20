# frozen_string_literal: true

# Bypass auth requirements
require_dependency 'covid_research/base_controller'

module CovidResearch
  module Volunteer
    class SubmissionsController < BaseController
      STATSD_KEY_PREFIX = STATSD_KEY_PREFIX + '.volunteer'

      def create
        with_monitoring do
          if form_service.valid?(payload)
            ConfirmationMailerJob.perform_async(payload['email'])
            deliver(payload)

            render json: { status: 'accepted' }, status: :accepted
          else
            StatsD.increment(STATSD_KEY_PREFIX + '.create.fail')

            error = {
              errors: form_service.submission_errors(payload)
            }
            render json: error, status: :unprocessable_entity
          end
        end
      end

      private

      def deliver(payload)
        form_service.queue_delivery(payload) if Flipper.enabled?(:covid_volunteer_delivery, @current_user)
      end

      def form_service
        @form_service ||= FormService.new
      end
    end
  end
end
