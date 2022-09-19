# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module RapidReadyForDecision
  class HypertensionProcessor < RrdProcessor
    def assess_data
      bp_observations = lighthouse_client.list_bp_observations
      claim_context.assessed_data = assess_hypertension(bp_observations)
      claim_context.sufficient_evidence = sufficient_evidence?

      return unless claim_context.sufficient_evidence

      # Add active medications to show in PDF
      med_requests = lighthouse_client.list_medication_requests
      claim_context.assessed_data[:medications] = filter_medications(med_requests)
    end

    def sufficient_evidence?
      claim_context.assessed_data[:bp_readings].present?
    end

    private

    # This will become a service in the new architecture
    def assess_hypertension(bp_observations)
      return {} if bp_observations.blank?

      relevant_readings = RapidReadyForDecision::LighthouseObservationData.new(bp_observations).transform
      { bp_readings: relevant_readings }
    end

    def filter_medications(medications)
      return [] if medications.blank?

      RapidReadyForDecision::LighthouseMedicationRequestData.new(medications).transform
    end

    def med_stats_hash(assessed_data)
      { bp_readings_count: assessed_data[:bp_readings]&.size, medications_count: assessed_data[:medications]&.size }
    end

    def generate_pdf
      # This will become a service in the new architecture
      RapidReadyForDecision::FastTrackPdfGenerator.new(claim_context.patient_info,
                                                       claim_context.assessed_data,
                                                       :hypertension).generate
    end
  end
end
