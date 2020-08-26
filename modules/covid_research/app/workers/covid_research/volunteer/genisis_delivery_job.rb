# frozen_string_literal: true

require 'sidekiq'

module CovidResearch
  module Volunteer
    class GenisisDeliveryJob
      include Sidekiq::Worker

      attr_reader :fmt, :service, :submitter

      def initialize(rf = RedisFormat, service = GenisisService)
        @fmt = rf.new
        @service = service
      end

      def perform(form_data)
        submission = fmt.from_redis(form_data)
        set_submission(submission)
        submitter.deliver_form

        handle_response(submitter.delivery_response)
      end

      def handle_response(response)
        raise GenisisDeliveryFailure.new(response.body, response.status) unless response.success?
      end

      private

      def set_submission(submission)
        @submitter ||= service.new(submission)
      end
    end

    class GenisisDeliveryFailure < StandardError
      def initialize(body, status)
        @body = body
        @status = status
      end

      def message
        "genISIS responded with: #{@status} #{@body}"
      end
    end
  end
end
