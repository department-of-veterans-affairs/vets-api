# frozen_string_literal: true

# Bypass authentication
require_dependency 'covid_vaccine_trial/application_controller'
require 'covid_vaccine_trial/form_schemas'

module CovidVaccineTrial
  class BaseController < ApplicationController
    @@screener_schema = FormSchemas.new.screener

    def self.screener
      @@screener_schema
    end

    def screener
      CovidVaccineTrial::BaseController.screener
    end

    private

    def validate_screener_schema
      unless screener.valid?(json_body)
        render json: {}, status: 422
      end
    end

    def form_attributes
      json_body.dig('data', 'attributes') || {}
    end

    def json_body
      JSON.parse(request.body.string)
    rescue JSON::ParserError
      error = {
        errors: [
          {
            type: 'malformed',
            detail: 'The payload body isn\'t valid JSON:API format',
            links: {
              about: 'https://jsonapi.org/format'
            }
          }
        ]
      }
      render json: error.to_json, status: 422
    end
  end
end