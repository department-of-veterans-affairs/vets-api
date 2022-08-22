# frozen_string_literal: true

module RapidReadyForDecision
  class Constants
    DISABILITIES = {
      hypertension: {
        code: 7101,
        label: 'hypertension',
        flipper_name: 'hypertension',
        sidekiq_job: 'RapidReadyForDecision::Form526BaseJob',
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

    # a classificationCode is derived from EVSS and is represented as a string
    PACT_CLASSIFICATION_CODES = [
      '3460', # hypertension
      '3370' # high blood pressure
    ].freeze

    MAS_DISABILITIES = [
      7528, # prostate cancer
      6847, # sleep apnea
      6522, # rhinitis
      6510, 6511, 6512, 6513, 6514 # sinusitus
    ].freeze

    # The key is associated with the `MAS_DISABILITIES` above, which are diagnostic codes.
    # The value is the contention codes -- see http://linktestbepbenefits.vba.va.gov:80/StandardDataService/StandardDataService
    # 9012: Respiratory
    # 8935: Cancer - Genitourinary
    # the classification codes must be strings
    MAS_RELATED_CONTENTIONS = {
      7528 => '8935',
      6847 => '9012',
      6522 => '9012',
      6510 => '9012',
      6511 => '9012',
      6512 => '9012',
      6513 => '9012',
      6514 => '9012'
    }.freeze

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

    class NoRrdProcessorForClaim < StandardError; end

    def self.processor(form526_submission)
      processor_class = processor_class(form526_submission)
      raise NoRrdProcessorForClaim unless processor_class

      processor_class.new(form526_submission)
    end
  end
end
