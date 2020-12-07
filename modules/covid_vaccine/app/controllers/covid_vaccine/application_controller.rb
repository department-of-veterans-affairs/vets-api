# frozen_string_literal: true

module CovidVaccine
  class ApplicationController < ::ApplicationController
    before_action :check_flipper

    def check_flipper
      routing_error unless Flipper.enabled?(:covid_vaccine_registration)
    end
  end
end
