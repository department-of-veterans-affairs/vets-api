# frozen_string_literal: true

module DependentsBenefits
  ##
  # Shared validation and schema logic for DependentsBenefits claims
  # Include in SavedClaim subclasses that handle dependents benefits forms
  #
  module ClaimBehavior
    extend ActiveSupport::Concern

    DEPENDENT_CLAIM_FLOWS = %w[
      report_death
      report_divorce
      add_child
      report_stepchild_not_in_household
      report_marriage_of_child_under18
      child_marriage
      report_child18_or_older_is_not_attending_school
      add_spouse
      add_disabled_child
    ].freeze

    # Checks if the claim was successfully submitted by checking the status of submission attempts
    # @return [Boolean] true if all submission attempts succeeded, false otherwise
    def submissions_succeeded?
      # TODO: Add checks for each submission type for claim
      bgs_submissions = BGS::Submission.where(saved_claim_id: id)
      return false if bgs_submissions.empty?

      bgs_submissions.all? { |submission| submission.latest_attempt&.status == 'submitted' }
    end

    ##
    # Validates whether the form matches the expected VetsJsonSchema::JSON schema
    #
    # @return [void]
    def form_matches_schema
      return unless form_is_string

      schema = VetsJsonSchema::SCHEMAS["#{self.class::FORM}-V2"]

      schema_errors = validate_schema(schema)
      unless schema_errors.empty?
        monitor.track_error_event('SavedClaim schema failed validation.', "#{stats_key}.schema_error",
                                  form_id:, errors: schema_errors)
      end

      validation_errors = validate_form(schema)
      validation_errors.each do |e|
        errors.add(e[:fragment], e[:message])
        e[:errors]&.flatten(2)&.each { |nested| errors.add(nested[:fragment], nested[:message]) if nested.is_a? Hash }
      end

      unless validation_errors.empty?
        monitor.track_error_event('SavedClaim form did not pass validation', "#{stats_key}.validation_error",
                                  form_id:, guid:, errors: validation_errors)
      end

      schema_errors.empty? && validation_errors.empty?
    end

    def to_pdf(file_name = nil)
      DependentsBenefits::PdfFill::Filler.fill_form(self, file_name)
    end

    def submittable_686?
      DEPENDENT_CLAIM_FLOWS.any? { |flow| parsed_form['view:selectable686_options'].include?(flow) }
    end

    def submittable_674?
      parsed_form.dig('view:selectable686_options', 'report674')
    end

    def add_veteran_info(user_data)
      parsed_form.merge!(user_data)
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
