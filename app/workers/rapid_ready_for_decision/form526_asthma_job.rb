# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module RapidReadyForDecision
  class Form526AsthmaJob < Form526BaseJob
    STATSD_KEY_PREFIX = 'worker.fast_track.form526_asthma_job'

    sidekiq_options retry: 2

    def assess_data(form526_submission)
      assessed_data = query_and_assess_lighthouse(form526_submission)

      return if assessed_data[:medications].blank?

      assessed_data
    end

    def release_pdf?(_form526_submission)
      disability_struct = RapidReadyForDecision::Constants::DISABILITIES[:asthma]
      Flipper.enabled?("rrd_#{disability_struct[:flipper_name].downcase}_release_pdf".to_sym)
    end

    private

    def query_and_assess_lighthouse(form526_submission)
      client = lighthouse_client(form526_submission)
      medications = assess_medications(client.list_resource('medication_requests'))
      { medications: medications }
    end

    def assess_medications(medications)
      return [] if medications.blank?

      RapidReadyForDecision::LighthouseMedicationRequestData.new(medications).transform
    end

    def med_stats_hash(_form526_submission, assessed_data)
      { medications_count: assessed_data[:medications]&.size }
    end

    def generate_pdf(form526_submission, assessed_data)
      RapidReadyForDecision::FastTrackPdfGenerator.new(patient_info(form526_submission),
                                                       assessed_data,
                                                       :asthma).generate
    end
  end
end
