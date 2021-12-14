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
      submission.start_evss_submission(nil, { submission_id: submission_id })
    end

    def perform(form526_submission_id, full_name)
      form526_submission = Form526Submission.find(form526_submission_id)
      client = Lighthouse::VeteransHealth::Client.new(get_icn(form526_submission))

      begin
        send_fast_track_stakeholder_email_for_testing(form526_submission_id)

        bp_readings = FastTrack::HypertensionObservationData.new(client.get_resource('observations')).transform
        return if no_recent_bp_readings(bp_readings)

        pdf = pdf(full_name, filtered_bp_readings(bp_readings),
                  filtered_medications(client.get_resource('medications')))

        upload_pdf_and_attach_special_issue(form526_submission, pdf)
      rescue => e
        Rails.logger.error 'Disability Compensation Fast Track Job failing for form' \
                           "id:#{form526_submission.id}. With error: #{e}"
        raise
      end
    end

    private

    def send_fast_track_stakeholder_email_for_testing(form526_submission_id)
      # TODO: This should be removed once we have basic metrics
      # on this feature and the visibility is imporved.
      ActionMailer::Base.mail(
        from: ApplicationMailer.default[:from],
        to: 'emily.theis@va.gov, zachary.goldfine@va.gov, Julia.Allen1@va.gov, paul.shute@va.gov',
        subject: 'Fast Track Hypertension Claim Submitted',
        body: "A claim was just submitted on the #{Rails.env} environment with submission id: #{form526_submission_id}"
      ).deliver_now
    end

    def get_icn(form526_submission)
      Account.where(idme_uuid: form526_submission.user_uuid).first.icn
    end

    def upload_pdf_and_attach_special_issue(form526_submission, pdf)
      FastTrack::HypertensionUploadManager.new(form526_submission).handle_attachment(pdf.render)
      if Flipper.enabled?(:disability_hypertension_compensation_fast_track_add_rrd)
        FastTrack::HypertensionSpecialIssueManager.new(form526_submission).add_special_issue
      end
    end

    def filtered_bp_readings(bp_readings)
      bp_readings = bp_readings.filter do |reading|
        reading[:issued].to_date > 1.year.ago
      end

      bp_readings.sort_by do |reading|
        reading[:issued].to_date
      end.reverse!
    end

    def filtered_medications(medication_request_response)
      medications = FastTrack::HypertensionMedicationRequestData.new(medication_request_response).transform

      medications.sort_by do |med|
        med[:authoredOn].to_date
      end.reverse!
    end

    def pdf(full_name, bpreadings, medications)
      FastTrack::HypertensionPdfGenerator.new(full_name, bpreadings, medications, Time.zone.today).generate
    end

    def no_recent_bp_readings(bp_readings)
      return true if bp_readings.blank?

      last_reading = bp_readings.map { |reading| reading[:issued] }.max
      last_reading < 1.year.ago
    end
  end
end
