# frozen_string_literal: true

module RapidReadyForDecision
  class Constants
    DISABILITIES = {
      hypertension: {
        code: 7101,
        label: 'hypertension',
        flipper_name: 'hypertension',
        sidekiq_job: 'RapidReadyForDecision::Form526HypertensionJob',
        processor_class: 'RapidReadyForDecision::HypertensionProcessor',
        backup_sidekiq_job: 'RapidReadyForDecision::DisabilityCompensationJob'
      },
      asthma: {
        code: 6602,
        label: 'asthma',
        flipper_name: 'asthma',
        sidekiq_job: 'RapidReadyForDecision::Form526AsthmaJob',
        processor_class: 'RapidReadyForDecision::AsthmaProcessor',
        keywords: %w[
          Aerochamber
          Albuterol
          Beclomethasone
          Benralizumab
          Budesonide
          Ciclesonide
          Fluticasone
          Levalbuterol
          Mepolizumab
          Methylprednisolone
          Mometasone
          Montelukast
          Omalizumab
          Prednisone
          Reslizumab
          Salmeterol
          Theophylline
          Zafirlukast
          Zileuton
          Asthma
          Breath
          Inhal
          Puff
          SOB
        ].map(&:downcase).freeze
      }
    }.freeze

    DISABILITIES_BY_CODE = DISABILITIES.map { |k, v| [v[:code], k] }.to_h

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

    def self.processor_class(form526_submission)
      disability_struct = first_disability(form526_submission)
      return unless disability_struct

      disability_struct[:processor_class]&.constantize
    end
  end
end
