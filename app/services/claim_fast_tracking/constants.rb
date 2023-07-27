# frozen_string_literal: true

module ClaimFastTracking
  class Constants
    DISABILITIES = {
      hypertension: {
        code: 7101,
        label: 'hypertension'
      },
      asthma: {
        code: 6602,
        label: 'asthma'
      }
    }.freeze

    DISABILITIES_BY_CODE = DISABILITIES.to_h { |k, v| [v[:code], k] }

    # @return [Array] mapping submitted disabilities to symbols used as keys for DISABILITIES;
    #                 an element is nil when the disability is not supported by RRD
    def self.extract_disability_symbol_list(form526_submission)
      form_disabilities = form526_submission.form.dig('form526', 'form526', 'disabilities')
      form_disabilities.map { |form_disability| DISABILITIES_BY_CODE[form_disability['diagnosticCode']] }
    end

    # @return [Hash] for the first RRD-supported disability in the form526_submission
    def self.first_disability(form526_submission)
      extracted_disability_symbols = extract_disability_symbol_list(form526_submission)
      return if extracted_disability_symbols.empty?

      disability_symbol = extracted_disability_symbols.first
      DISABILITIES[disability_symbol]
    end
  end
end
