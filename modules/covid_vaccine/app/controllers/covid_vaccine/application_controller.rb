# frozen_string_literal: true

module CovidVaccine
  class ApplicationController < ::ApplicationController
    service_tag 'covid-vaccine'
    before_action :check_flipper
    skip_before_action :authenticate
    before_action :validate_session

    protected

    def check_flipper
      routing_error unless Flipper.enabled?(:covid_vaccine_registration)
    end

    def authorize
      raise_access_denied unless @current_user&.loa3?
    end

    def raise_access_denied
      raise Common::Exceptions::Unauthorized, detail: 'You do not have access to the requested resource'
    end
  end
end
