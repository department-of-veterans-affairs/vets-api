# frozen_string_literal: true

require 'claims_evidence_api/json_schema'

module ClaimsEvidenceApi
  module Validation
    module SearchFilters
      class << self
        def validate(filters)
          JSON::Validator.validate!(ClaimsEvidenceApi::JsonSchema::SEARCH_FILTERS, filters)
          filters
        end

        def transform(filters)
          transformed = filters.each_with_object({}) { |(filter, value), formatted|
            next unless (formatter = FORMATTERS[filter.to_sym])

            formatted[formatter.search_field] = {
              evaluationType: formatter.evaluation,
              value: value.is_a?(String) ? value : value.to_json
            }
          }
          validate(transformed)
        end

        def formatters
          filters = JSON.parse(File.read(ClaimsEvidenceApi::JsonSchema::SEARCH_FILTERS))['properties']
          filters = filters.each_with_object([]) { |(search_field, props), formats|
            file = "#{ClaimsEvidenceApi::JsonSchema::SCHEMA}/#{props['$ref']}"
            next unless (filter = JSON.parse(File.read(file))) rescue nil

            formats << OpenStruct.new(
              filter: File.basename(file, 'Filter.json').to_sym,
              file:,
              search_field:,
              evaluation: filter['properties']['evaluationType']['enum'].first,
              value_type: filter['properties']['value']['type'].to_s
            )
          }

          filters.compact.index_by(&:filter)
        end
      end

      FORMATTERS = formatters.freeze
    end
  end
end
