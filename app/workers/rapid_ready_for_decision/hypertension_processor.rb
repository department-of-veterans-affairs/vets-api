# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module RapidReadyForDecision
  class HypertensionProcessor < RrdProcessor
    def assess_data
      assessed_data = query_and_assess_lighthouse

      return if assessed_data[:bp_readings].blank?

      assessed_data
    end

    private

    def query_and_assess_lighthouse
      client = lighthouse_client
      bp_readings = assess_bp_readings(client.list_resource('observations'))
      # stop querying if bp_readings.blank?
      medications = assess_medications(client.list_resource('medication_requests')) if bp_readings.present?

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

    def generate_pdf(assessed_data)
      RapidReadyForDecision::FastTrackPdfGenerator.new(patient_info,
                                                       assessed_data,
                                                       :hypertension).generate
    end
  end
end
