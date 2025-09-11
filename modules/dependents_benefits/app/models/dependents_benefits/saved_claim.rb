# frozen_string_literal: true

module DependentsBenefits
  ##
  # DependentsBenefit 686C-674 Active::Record
  # @see app/model/saved_claim
  #
  # todo: migrate encryption to DependentsBenefits::SavedClaim, remove inheritance and encryption shim
  class SavedClaim < ::SavedClaim
    # We want to use the `Type` behavior but we want to override it with our custom type default scope behaviors.
    self.inheritance_column = :_type_disabled

    # We want to override the `Type` behaviors for backwards compatability
    default_scope -> { where(type: 'SavedClaim::DependencyClaim') }, all_queries: true

    ##
    # The KMS Encryption Context is preserved from the saved claim model namespace we migrated from
    # ***********************************************************************************
    # Note: This CAN NOT be removed as long as there are existing records of this type. *
    # ***********************************************************************************
    #
    def kms_encryption_context
      {
        model_name: 'SavedClaim::DependencyClaim',
        model_id: id
      }
    end

    # DependentsBenefit Form ID
    FORM = DependentsBenefits::FORM_ID

    ##
    # Validates whether the form matches the expected VetsJsonSchema::JSON schema
    #
    # @return [void]
    def form_matches_schema
      return unless form_is_string

      # TODO: Use the form_id from the saved claim when we have multiple forms
      schema = VetsJsonSchema::SCHEMAS['686C-674-V2']

      schema_errors = validate_schema(schema)
      unless schema_errors.empty?
        monitor.track_error_event('SavedClaim schema failed validation.', "#{stats_key}.schema_error",
                                  { form_id:, errors: schema_errors })
      end

      validation_errors = validate_form(schema)
      validation_errors.each do |e|
        errors.add(e[:fragment], e[:message])
        e[:errors]&.flatten(2)&.each { |nested| errors.add(nested[:fragment], nested[:message]) if nested.is_a? Hash }
      end

      unless validation_errors.empty?
        monitor.track_error_event('SavedClaim form did not pass validation', "#{stats_key}.validation_error",
                                  { form_id:, guid:, errors: validation_errors })
      end

      schema_errors.empty? && validation_errors.empty?
    end

    private

    def validate_form(schema)
      camelized_data = deep_camelize_keys(parsed_form)

      errors = JSONSchemer.schema(schema).validate(camelized_data).to_a
      return [] if errors.empty?

      reformatted_schemer_errors(errors)
    end

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

    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end

    def stats_key
      'api.dependents_claim'
    end
  end
end
