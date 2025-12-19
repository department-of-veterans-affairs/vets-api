# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class Immunization
    include Vets::Model

    attribute :id, String
    attribute :cvx_code, Integer
    attribute :date, String # This might be a full ISO string or just the year or year-month or year-month-day
    attribute :sort_date, String # Normalized date for sorting (internal use only)
    attribute :dose_number, String
    attribute :dose_series, String
    attribute :group_name, String
    attribute :location, String
    attribute :location_id, String
    attribute :manufacturer, String
    attribute :note, String
    attribute :reaction, String
    attribute :short_description, String
    attribute :administration_site, String
    attribute :lot_number, String
    attribute :status, String

    default_sort_by sort_date: :desc
  end
end
