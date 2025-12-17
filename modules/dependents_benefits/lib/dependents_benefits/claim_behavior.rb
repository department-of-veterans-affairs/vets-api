# frozen_string_literal: true

module DependentsBenefits
  ##
  # Shared validation and schema logic for DependentsBenefits claims
  # Include in SavedClaim subclasses that handle dependents benefits forms
  #
  module ClaimBehavior
    extend ActiveSupport::Concern

    # Fields indicating that a 686 dependent claim is being made
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
    #
    # @todo Add checks for each submission type for claim
    # @return [Boolean] true if all submission attempts succeeded, false otherwise
    def submissions_succeeded?
      submitted_to_bgs? && submitted_to_claims_evidence_api?
    end

    # Checks if the claim was successfully submitted to BGS
    def submitted_to_bgs?
      submissions = BGS::Submission.where(saved_claim_id: id)
      submissions.exists? && submissions.all? { |submission| submission.latest_attempt&.status == 'submitted' }
    end

    # Checks if the claim was successfully submitted to Claims Evidence API
    def submitted_to_claims_evidence_api?
      submissions = ClaimsEvidenceApi::Submission.where(saved_claim_id: id)
      submissions.exists? && submissions.all? { |submission| submission.latest_attempt&.status == 'accepted' }
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
        monitor.track_error_event('Dependents Benefits schema failed validation.', "#{stats_key}.schema_error",
                                  form_id:, errors: schema_errors)
      end

      validation_errors = validate_form(schema)
      validation_errors.each do |e|
        errors.add(e[:fragment], e[:message])
        e[:errors]&.flatten(2)&.each { |nested| errors.add(nested[:fragment], nested[:message]) if nested.is_a? Hash }
      end

      unless validation_errors.empty?
        monitor.track_error_event('Dependents Benefits form did not pass validation.', "#{stats_key}.validation_error",
                                  form_id:, guid:, errors: validation_errors)
      end

      schema_errors.empty? && validation_errors.empty?
    end

    # Generates a PDF representation of the claim form
    #
    # @param file_name [String, nil] Optional custom filename for the generated PDF
    # @return [String] Path to the generated PDF file
    def to_pdf(file_name = nil)
      DependentsBenefits::PdfFill::Filler.fill_form(self, file_name)
    end

    # Checks if the claim contains a submittable 686 form
    #
    # Determines whether any of the dependent claim flows selected in the form
    # match the defined DEPENDENT_CLAIM_FLOWS for form 686
    #
    # @return [Boolean] true if the form includes valid 686 claim flows, false otherwise
    def submittable_686?
      DEPENDENT_CLAIM_FLOWS.any? { |flow| parsed_form['view:selectable686_options'].include?(flow) }
    end

    # Checks if the claim contains a submittable 674 form
    #
    # Determines whether the report674 option is selected in the form,
    # indicating a student dependency claim
    #
    # @return [Boolean, nil] true if report674 is selected, false/nil otherwise
    def submittable_674?
      parsed_form.dig('view:selectable686_options', 'report674')
    end

    # Adds veteran information to the parsed form
    #
    # Merges the provided user data (containing veteran information) into the
    # claim's parsed form, modifying it in place
    #
    # @param user_data [Hash] Hash containing veteran information to merge
    # @return [Hash] The updated parsed form with veteran information merged
    def add_veteran_info(user_data)
      parsed_form.merge!(user_data)
    end

    # Checks if claim is pension related submission
    #
    # @return [Boolean] true if the submission is pension related, false otherwise
    def pension_related_submission?
      return false unless Flipper.enabled?(:va_dependents_net_worth_and_pension)

      # We can determine pension-related submission by checking if
      # household income or student income info was asked on the form
      household_income_present = parsed_form['dependents_application']&.key?('household_income')
      student_income_present = parsed_form.dig('dependents_application', 'student_information')&.any? do |student|
        student&.key?('student_networth_information')
      end

      !!(household_income_present || student_income_present)
    end

    # Generates a folder identifier string for organizing veteran claims
    #
    # Creates an identifier starting with 'VETERAN' and appends the first available
    # identifier from SSN, participant_id, or ICN in that order of priority
    #
    # @return [String] Folder identifier in format 'VETERAN' or 'VETERAN:TYPE:VALUE'
    # @example
    #   folder_identifier #=> "VETERAN:SSN:123456789"
    #   folder_identifier #=> "VETERAN:ICN:1234567890V123456"
    def folder_identifier
      fid = 'VETERAN'
      { ssn:, participant_id:, icn: }.each do |k, v|
        if v.present?
          fid += ":#{k.to_s.upcase}:#{v}"
          break
        end
      end

      fid
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

    # Returns a memoized instance of the DependentsBenefits monitor
    #
    # @return [DependentsBenefits::Monitor] Monitor instance for tracking events and errors
    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end

    # Returns the StatsD key prefix for tracking claim metrics
    #
    # @return [String] The stats key prefix 'api.dependents_claim'
    def stats_key
      'api.dependents_claim'
    end

    # Extracts the veteran's Social Security Number from the parsed form
    #
    # @return [String, nil] The veteran's SSN or nil if not present
    def ssn
      parsed_form&.dig('veteran_information', 'ssn')
    end

    # Extracts the veteran's participant ID from the parsed form
    #
    # @return [String, nil] The veteran's participant ID or nil if not present
    def participant_id
      parsed_form&.dig('veteran_information', 'participant_id')
    end

    # Extracts the veteran's Integration Control Number (ICN) from the parsed form
    #
    # @return [String, nil] The veteran's ICN or nil if not present
    def icn
      parsed_form&.dig('veteran_information', 'icn')
    end
  end
end
