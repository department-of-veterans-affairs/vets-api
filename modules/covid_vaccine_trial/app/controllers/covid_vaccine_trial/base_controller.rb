# frozen_string_literal: true

# Bypass authentication
require_dependency 'covid_vaccine_trial/application_controller'

module CovidVaccineTrial
  class BaseController < ApplicationController
    include Common::Client::Concerns::Monitoring
    include SentryLogging

    STATSD_KEY_PREFIX = 'api.covid_vaccine'

    private

    def payload
      JSON.parse(request.body.string) # Ditch :format, :controller and friends
    end
  end
end