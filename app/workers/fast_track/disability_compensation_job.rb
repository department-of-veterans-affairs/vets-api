# frozen_string_literal: true

require 'prawn'
require 'prawn/table'
require 'lighthouse/veterans_health/client'

module FastTrack
  class DisabilityCompensationJob
    include Sidekiq::Worker

    extend SentryLogging
    # NOTE: This is apparently at most about 4.5 hours.
    # https://github.com/mperham/sidekiq/issues/2168#issuecomment-72079636
    sidekiq_options retry: 8

    sidekiq_retries_exhausted do |msg, _ex|
      submission_id = msg['args'].first
      submission = Form526Submission.new
      submission.start_evss_submission(_status, { submission_id: submission_id })
    end

    def perform(form526_submission_id, full_name)
      form526_submission = Form526Submission.find(form526_submission_id)
      icn = Account.where(idme_uuid: form526_submission.user_uuid).first.icn

      client = Lighthouse::VeteransHealth::Client.new(icn)
      observations_response = client.get_resource('observations')
      medicationrequest_response = client.get_resource('medications')

      begin
        bpreadings = FastTrack::HypertensionObservationData.new(observations_response).transform
        return if no_recent_bp_readings(bpreadings)

        medications = FastTrack::HypertensionMedicationRequestData.new(medicationrequest_response).transform

        bpreadings = bpreadings.filter { |reading| reading[:issued].to_date > 1.year.ago }

        bpreadings = bpreadings.sort_by { |reading| reading[:issued].to_date }.reverse!
        medications = medications.sort_by { |med| med[:authoredOn].to_date }.reverse!

        pdf = FastTrack::HypertensionPdfGenerator.new(full_name, bpreadings, medications, Time.zone.today).generate

        FastTrack::HypertensionUploadManager.new(form526_submission).handle_attachment(pdf.render)

        FastTrack::HypertensionSpecialIssueManager.new(form526_submission).add_special_issue
      rescue => e
        Rails.logger.error 'Disability Compensation Fast Track Job failing for form' \
                           "id:#{form526_submission.id}. With error: #{e}"
        raise
      end
    end

    private

    def no_recent_bp_readings(bp_readings)
      return true if bp_readings.blank?

      last_reading = bp_readings.map { |reading| reading[:issued] }.max
      last_reading < 1.year.ago
    end
  end
end
