# frozen_string_literal: true

# Bypass authentication
require_dependency 'covid_research/application_controller'

module CovidResearch
  class BaseController < ApplicationController
    include Common::Client::Concerns::Monitoring
    include SentryLogging

    STATSD_KEY_PREFIX = 'api.covid_research'

    private

    def payload
      JSON.parse(request.body.string) # Ditch :format, :controller and friends
    end
  end
end