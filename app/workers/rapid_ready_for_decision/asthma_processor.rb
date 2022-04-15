# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module RapidReadyForDecision
  class AsthmaProcessor < RrdProcessor
    def assess_data
      assessed_data = query_and_assess_lighthouse

      return if assessed_data[:medications].blank?

      assessed_data
    end

    def release_pdf?
      disability_struct = RapidReadyForDecision::Constants::DISABILITIES[:asthma]
      Flipper.enabled?("rrd_#{disability_struct[:flipper_name].downcase}_release_pdf".to_sym)
    end

    private

    def query_and_assess_lighthouse
      client = lighthouse_client
      medications = assess_medications(client.list_resource('medication_requests'))
      { medications: medications }
    end

    def assess_medications(medications)
      return [] if medications.blank?

      RapidReadyForDecision::LighthouseMedicationRequestData.new(medications).transform
    end

    def med_stats_hash(assessed_data)
      { medications_count: assessed_data[:medications]&.size }
    end

    def generate_pdf(assessed_data)
      RapidReadyForDecision::FastTrackPdfGenerator.new(patient_info,
                                                       assessed_data,
                                                       :asthma).generate
    end
  end
end
