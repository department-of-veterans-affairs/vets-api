# frozen_string_literal: true

module DependentsBenefits
  module ClaimBehavior
    ##
    # Methods for form schema validation and data transformation
    #
    module FormValidation
      extend ActiveSupport::Concern

      # @see ::SavedClaim#form_schema
      # @see DependentsBenefits::FORM_SCHEMA_BASE
      def form_schema(form_id)
        path = "#{DependentsBenefits::FORM_SCHEMA_BASE}/#{form_id.sub('-V2', '')}.json"
        MultiJson.load(File.read(path))
      end

      ##
      # Validates whether the form matches the expected VetsJsonSchema::JSON schema
      #
      # @return [void]
      def form_matches_schema
        return unless form_is_string

        schema = form_schema(form_id)

        schema_errors = validate_schema(schema)
        unless schema_errors.empty?
          monitor.track_error_event('Dependents Benefits schema failed validation.', "#{stats_key}.schema_error",
                                    form_id:, errors: schema_errors)
        end

        validation_errors = validate_form(schema)
        validation_errors.each do |e|
          errors.add(e[:fragment], e[:message])
          e[:errors]&.flatten(2)&.each { |nested| errors.add(nested[:fragment], nested[:message]) if nested.is_a? Hash }
        end

        unless validation_errors.empty?
          monitor.track_error_event('Dependents Benefits form did not pass validation.',
                                    "#{stats_key}.validation_error",
                                    form_id:, guid:, errors: validation_errors)
        end

        schema_errors.empty? && validation_errors.empty?
      end

      private

      # Validates the form data against the provided JSON schema
      #
      # Camelizes the form keys to match schema expectations and validates using JSONSchemer.
      # Returns reformatted error messages if validation fails.
      #
      # @param schema [Hash] The JSON schema to validate against
      # @return [Array<Hash>] Array of validation errors, empty if validation succeeds
      def validate_form(schema)
        camelized_data = deep_camelize_keys(parsed_form)

        errors = JSONSchemer.schema(schema).validate(camelized_data).to_a
        return [] if errors.empty?

        reformatted_schemer_errors(errors)
      end

      # Recursively camelizes all keys in a nested data structure
      #
      # Transforms hash keys to lower camelCase format and recursively processes
      # nested hashes and arrays. Non-hash/array values are returned unchanged.
      #
      # @param data [Hash, Array, Object] The data structure to camelize
      # @return [Hash, Array, Object] The data structure with camelized keys
      def deep_camelize_keys(data)
        case data
        when Hash
          data.transform_keys { |key| key.to_s.camelize(:lower) }
              .transform_values { |value| deep_camelize_keys(value) }
        when Array
          data.map { |item| deep_camelize_keys(item) }
        else
          data
        end
      end
    end
  end
end
