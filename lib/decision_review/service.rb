# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'

require 'decision_review/configuration'
require 'decision_review/responses/response'
require 'decision_review/service_exception'

# Proxy Service for calling Lighthouse Decision Reviews API
module DecisionReview
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    configuration DecisionReview::Configuration

    STATSD_KEY_PREFIX = 'api.decision_review'

    attr_reader :request, :response

    def initialize(request_data)
      @request = Request.new request_data
      @response = Response.new raw_response
    end

    def raw_response
      @raw_response ||= with_monitoring { perform(*request.perform_args) }
    end
  end
end
