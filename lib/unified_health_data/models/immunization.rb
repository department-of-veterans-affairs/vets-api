# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class Immunization
    include Vets::Model

    attribute :id, String
    attribute :cvx_code, Integer
    attribute :date, String # ISO 8601 datetime string or partial date (e.g., '2024', '2024-11', '2024-11-26')
    attribute :sort_date, String # Normalized date for sorting (internal use only)
    attribute :dose_number, String
    attribute :dose_series, String
    attribute :group_name, String
    attribute :location, String
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
