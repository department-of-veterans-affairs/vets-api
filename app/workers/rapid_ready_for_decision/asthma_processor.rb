# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module RapidReadyForDecision
  class AsthmaProcessor < RrdProcessor
    def assess_data
      med_requests = lighthouse_client.list_medication_requests
      claim_context.assessed_data = assess_asthma(med_requests)
      claim_context.sufficient_evidence = sufficient_evidence?
    end

    def sufficient_evidence?
      claim_context.assessed_data[:medications].present?
    end

    private

    ASTHMA_KEYWORDS = RapidReadyForDecision::Constants::DISABILITIES[:asthma][:keywords]

    # This will become a service in the new architecture
    def assess_asthma(medications)
      return {} if medications.blank?

      transformed_medications = RapidReadyForDecision::LighthouseMedicationRequestData.new(medications).transform
      flagged_medications = transformed_medications.map do |medication|
        {
          **medication,
          flagged: ASTHMA_KEYWORDS.any? { |keyword| medication.to_s.downcase.include?(keyword) }
        }
      end
      medications = flagged_medications.sort_by { |medication| medication[:flagged] ? 0 : 1 }
      { medications: }
    end

    def med_stats_hash(assessed_data)
      {
        medications_count: assessed_data[:medications]&.size,
        asthma_medications_count: assessed_data[:medications].select { |m| m[:flagged] }.size
      }
    end

    def generate_pdf
      # This will become a service in the new architecture
      RapidReadyForDecision::FastTrackPdfGenerator.new(claim_context.patient_info,
                                                       claim_context.assessed_data,
                                                       :asthma).generate
    end
  end
end
