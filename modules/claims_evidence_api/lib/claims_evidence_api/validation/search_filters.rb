# frozen_string_literal: true

require 'claims_evidence_api/json_schema'

module ClaimsEvidenceApi
  module Validation
    # validation and transfomation specific to the available filters for search
    module SearchFilters
      class << self
        # validate the Filters
        #
        # @param filters [Hash] list of search filters; @see schema/filters
        #
        # @return [Hash] valid filter list
        # @raise JSON::Schema::ValidationError
        def validate(filters)
          JSON::Validator.validate!(ClaimsEvidenceApi::JsonSchema::SEARCH_FILTERS, filters)
          filters
        end

        # given a map of filter ids to values, transform them into the expected json schema structure.
        # this is a utility to ease the caller burden, ie. no prior knowledge of the schema structure.
        # the filter id will be equivalent to the filter filename with 'Filter.json' removed
        #
        # @see ClaimsEvidenceApi::Service::Search#find
        # @see #validate
        # @see #formatters
        #
        # @example
        #   transform({ contentSource: 'VA.gov', notValidField: 'will be removed' })
        #   >> { 'providerData.contentSource' => { evaluationType: 'EQUALS', value: 'VA.gov' } }
        #
        # @param filters [Hash] key-value pairs to transform
        #
        # @return [Hash] valid json schema hash for use in search
        # @raise JSON::Schema::ValidationError
        def transform(filters)
          transformed = filters.each_with_object({}) do |(filter, value), xformed|
            next unless (formatter = FORMATTERS[filter.to_sym])

            xfrmd_value = value.to_json if formatter.value_type == 'string' && !value.is_a?(String)

            xformed[formatter.search_field] = {
              evaluationType: formatter.evaluation,
              value: xfrmd_value || value
            }
          end
          validate(transformed)
        end

        # assemble the list of valid filter fields to be used in #transform
        # @see #transform
        #
        # @return [Hash] map of filter id to formatter structure
        def formatters
          filters = JSON.parse(File.read(ClaimsEvidenceApi::JsonSchema::SEARCH_FILTERS))['properties']
          filters = filters.each_with_object([]) do |(search_field, props), formats|
            file = "#{ClaimsEvidenceApi::JsonSchema::SCHEMA}/#{props['$ref']}"
            begin
              next unless (filter = JSON.parse(File.read(file)))
            rescue
              nil
            end

            formats << OpenStruct.new(
              filter: File.basename(file, 'Filter.json').to_sym,
              file:,
              search_field:,
              evaluation: filter['properties']['evaluationType']['enum'].first,
              value_type: filter['properties']['value']['type'].to_s
            )
          end

          filters.compact.index_by(&:filter)
        end
      end

      # map of formatters that can be used to transform key-value pairs to the expected schema
      FORMATTERS = formatters.freeze
    end
  end
end
