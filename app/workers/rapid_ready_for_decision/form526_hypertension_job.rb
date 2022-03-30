# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module RapidReadyForDecision
  class Form526HypertensionJob < Form526BaseJob
    STATSD_KEY_PREFIX = 'worker.fast_track.form526_hypertension_job'

    sidekiq_options retry: 2

    def assess_data(form526_submission)
      assessed_data = query_and_assess_lighthouse(form526_submission)

      return if assessed_data[:bp_readings].blank?

      assessed_data
    end

    private

    def patient_info(form526_submission)
      form526_submission.full_name.merge(birthdate: form526_submission.auth_headers['va_eauth_birthdate'])
    end

    def query_and_assess_lighthouse(form526_submission)
      client = lighthouse_client(form526_submission)
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

    def med_stats_hash(_form526_submission, assessed_data)
      { bp_readings_count: assessed_data[:bp_readings]&.size }
    end

    def generate_pdf(form526_submission, assessed_data)
      RapidReadyForDecision::FastTrackPdfGenerator.new(patient_info(form526_submission),
                                                       assessed_data[:bp_readings],
                                                       assessed_data[:medications]).generate
    end
  end
end
