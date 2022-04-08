# frozen_string_literal: true

module RapidReadyForDecision
  class Constants
    DISABILITIES = {
      hypertension: {
        code: 7101,
        label: 'hypertension',
        flipper_name: 'hypertension',
        sidekiq_job: 'RapidReadyForDecision::Form526HypertensionJob',
        backup_sidekiq_job: 'RapidReadyForDecision::DisabilityCompensationJob'
      },
      asthma: {
        code: 6602,
        label: 'asthma',
        flipper_name: 'asthma',
        sidekiq_job: 'RapidReadyForDecision::Form526AsthmaJob'
      }
    }.freeze

    DISABILITIES_BY_CODE = DISABILITIES.map { |k, v| [v[:code], k] }.to_h

    # @return [Array] mapping submitted disabilities to symbols used as keys for DISABILITIES;
    #                 an element is nil when the disability is not supported by RRD
    def self.extract_disability_symbol_list(form526_submission)
      form_disabilities = form526_submission.form.dig('form526', 'form526', 'disabilities')
      form_disabilities.map { |form_disability| DISABILITIES_BY_CODE[form_disability['diagnosticCode']] }
    end
  end
end
