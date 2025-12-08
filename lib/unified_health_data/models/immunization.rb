# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class Immunization
    include Vets::Model

    attribute :id, String
    attribute :cvx_code, Integer
    attribute :date, String # This might be a full datetime object or just the year or year-month or year-month-day
    attribute :dose_number, String
    attribute :dose_series, String
    attribute :group_name, String
    attribute :location, String
    attribute :location_id, String
    attribute :manufacturer, String
    attribute :note, String
    attribute :reaction, String
    attribute :short_description, String
  end
end
