# frozen_string_literal: true

module IvcChampva
  class PromptManager
    PROMPTS_DIR = Rails.root.join('modules', 'ivc_champva', 'config', 'prompts').to_s

    # Mapping of document types to their corresponding prompt files
    DOCTYPE_PROMPT_MAP = {
      'EOB' => 'doc_validation',
      'pharmacy invoice' => 'doc_validation',
      'medical invoice' => 'doc_validation'
    }.freeze

    # Document type definitions for replacement
    DOCTYPE_DEFINITIONS = {
      'EOB' => 'EOB (Explanation of Benefits)',
      'pharmacy invoice' => 'PharmacyBill (pharmacy bill/invoice)',
      'medical invoice' => 'MedicalBill (medical bill/invoice)'
    }.freeze

    # Expected fields for each document type
    EXPECTED_FIELDS = {
      'EOB' => [
        'Date of Service',
        'Provider Name',
        'Provider NPI (10-digit)',
        'Services Paid For (CPT/HCPCS code or description)',
        'Amount Paid by Insurance'
      ],
      'medical invoice' => [
        'Beneficiary Full Name',
        'Beneficiary Date of Birth',
        'Provider Full Name',
        'Provider Medical Title',
        'Provider Service Address',
        'Provider NPI (10-digit)',
        'Provider Tax ID (9-digit)',
        'Charges List',
        'Date of Service',
        'Diagnosis (DX) Codes',
        'Procedure Codes (CPT or HCPCS)'
      ],
      'pharmacy invoice' => [
        'Pharmacy Name',
        'Pharmacy Address',
        'Pharmacy Phone Number',
        'Medication Name',
        'Medication Dosage',
        'Medication Strength',
        'Medication Quantity',
        'Cost of Medication',
        'Copay Amount',
        'National Drug Code (NDC, 11-digit)',
        'Date Prescription Filled',
        'Prescriber Name'
      ]
    }.freeze

    class << self
      ##
      # Get prompt based on document type key
      #
      # @param key [String, nil] the document type key (e.g., 'EOB', 'pharmacy invoice', 'medical invoice')
      # @return [String] the appropriate prompt content
      def get_prompt(key = nil)
        # Use default prompt if key is not one of our supported document types
        unless DOCTYPE_PROMPT_MAP.key?(key)
          Rails.logger.info("IvcChampva::PromptManager using default prompt for #{key}")
          return read_prompt('default_doc_validation')
        end

        # Load the generic template and perform replacements
        template = read_prompt(DOCTYPE_PROMPT_MAP[key])

        # Replace placeholders with document-specific values
        document_type = DOCTYPE_DEFINITIONS[key]
        expected_fields = format_expected_fields(EXPECTED_FIELDS[key])

        result = template.gsub('%DOCUMENT_TYPE%', document_type)
                         .gsub('%EXPECTED_FIELDS%', expected_fields)

        Rails.logger.info("IvcChampva::PromptManager generated prompt for #{key}")
        result
      end

      private

      ##
      # Read a prompt from a text file
      #
      # @param prompt_name [String] the name of the prompt file (without .txt extension)
      # @return [String] the prompt content
      def read_prompt(prompt_name)
        prompt_path = File.join(PROMPTS_DIR, "#{prompt_name}.txt")

        raise ArgumentError, "Prompt file not found: #{prompt_path}" unless File.exist?(prompt_path)

        File.read(prompt_path).strip
      end

      ##
      # Get the default prompt for document validation
      #
      # @return [String] the default prompt content
      def default_doc_validation_prompt
        read_prompt('default_doc_validation')
      end

      ##
      # Format expected fields list for prompt insertion
      #
      # @param fields [Array<String>] list of expected fields
      # @return [String] formatted field list
      def format_expected_fields(fields)
        fields.map { |field| "     * #{field}" }.join("\n")
      end
    end
  end
end
