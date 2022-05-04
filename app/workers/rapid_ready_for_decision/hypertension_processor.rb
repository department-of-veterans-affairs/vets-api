# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module RapidReadyForDecision
  class HypertensionProcessor < RrdProcessor
    def assess_data
      claim_context.assessed_data = query_and_assess_lighthouse
      claim_context.sufficient_evidence = claim_context.assessed_data[:bp_readings].present?
    end

    private

    def query_and_assess_lighthouse
      client = lighthouse_client
      bp_readings = assess_bp_readings(client.list_bp_observations)
      # stop querying if bp_readings.blank?
      medications = assess_medications(client.list_medication_requests) if bp_readings.present?

      {
        bp_readings: bp_readings,
        medications: medications
      }
    end

    def assess_bp_readings(bp_readings)
      return [] if bp_readings.blank?

      RapidReadyForDecision::LighthouseObservationData.new(bp_readings).transform
    end

    def assess_medications(medications)
      return [] if medications.blank?

      RapidReadyForDecision::LighthouseMedicationRequestData.new(medications).transform
    end

    def med_stats_hash(assessed_data)
      { bp_readings_count: assessed_data[:bp_readings]&.size }
    end

    def generate_pdf
      RapidReadyForDecision::FastTrackPdfGenerator.new(claim_context.patient_info,
                                                       claim_context.assessed_data,
                                                       :hypertension).generate
    end
  end
end
