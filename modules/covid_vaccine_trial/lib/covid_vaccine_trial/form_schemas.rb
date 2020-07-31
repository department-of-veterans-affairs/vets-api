# frozen_string_literal: true

require 'json_schemer'

module CovidVaccineTrial
  class FormSchemas
    def screener
      @screener ||= JSONSchemer.schema(JSON.parse(File.read(File.join(base_dir, 'covid-vaccine-trial-schema.json'))))
    end

    def base_dir
      Rails.root.join('modules', 'covid_vaccine_trial', 'config', 'schemas')
    end
  end
end