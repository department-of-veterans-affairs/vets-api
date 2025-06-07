# frozen_string_literal: true

require 'vets/model'

module Lighthouse
  module VeteransHealth
    module Models
      class ImmunizationAttributes
        include Vets::Model

        attribute :cvx_code, Integer
        attribute :date, DateTime
        attribute :dose_number, Integer
        attribute :dose_series, Integer
        attribute :group_name, String
        attribute :manufacturer, String
        attribute :note, String
        attribute :reaction, String
        attribute :short_description, String
      end

      class Immunization
        include Vets::Model

        attribute :id, String
        attribute :type, String, default: 'immunization'
        attribute :attributes, ImmunizationAttributes
        attribute :relationships, Hash

        # Custom JSON serialization
        def as_json(_options = {})
          {
            id:,
            type:,
            attributes:,
            relationships:
          }.compact
        end
      end
    end
  end
end
