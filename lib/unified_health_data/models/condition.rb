# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class Condition
    include Vets::Model

    attribute :id, String
    attribute :date, String
    attribute :sort_date, String # Normalized date for sorting (internal use only)
    attribute :name, String
    attribute :provider, String
    attribute :facility, String
    attribute :comments, Array

    default_sort_by sort_date: :desc
  end
end
