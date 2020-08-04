# frozen_string_literal: true

# Bypass authentication
require_dependency 'covid_vaccine_trial/application_controller'

module CovidVaccineTrial
  class BaseController < ApplicationController
    private

    def payload
      JSON.parse(request.body.string) # Ditch :format, :controller and friends
  end
end