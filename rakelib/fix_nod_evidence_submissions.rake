# frozen_string_literal: true

require 'decision_review_v1/service'

namespace :decision_reviews do
  desc 'Enqueue jobs for NOD V2 submissions with evidence uploads that did not get uploaded to Lighthouse'
  task fix_nod_evidence_submissions: :environment do
    # The bulk of the code is below; `build_upload_metadata` and `complete_nod_evidence_submissions` methods
    # are helpers

    def build_upload_metadata(auth_headers, form_data)
      # This is a proxy for the User object that we do not have access to in this rake task
      user_object_class = Class.new do
        attr_reader :first_name, :last_name, :postal_code, :ssn

        def initialize(first_name, last_name, postal_code, ssn)
          @first_name = first_name
          @last_name = last_name
          @postal_code = postal_code
          @ssn = ssn
        end
      end

      user = user_object_class.new(
        auth_headers['X-VA-First-Name'].humanize,
        auth_headers['X-VA-Last-Name'].humanize,
        form_data['data']['attributes']['veteran']['address']['zipCode5'],
        auth_headers['X-VA-File-Number']
      )
      DecisionReviewV1::Service.file_upload_metadata(user)
    end

    def complete_nod_evidence_submissions(nod)
      form_attachment_guids = nod.form_data['nodUploads'].pluck('confirmationCode')
      form_attachments = FormAttachment.where(guid: form_attachment_guids)
      appeal_submission = AppealSubmission.find_by!(submitted_appeal_uuid: nod.id)
      auth_headers = nod.auth_headers
      # We've verified that this information exists for all 48 Lighthouse NOD form submission records

      # New NOD submission pathway failed to set these values
      # which are necessary for the evidence upload job to run successfully
      appeal_submission.update!(
        board_review_option: nod.board_review_option,
        upload_metadata: build_upload_metadata(auth_headers, nod.form_data)
      )
      # There will be 48 sets of form_attachments
      form_attachments.map do |fa|
        # Similar to above, new NOD submission pathway failed to create these records,
        # which are necessary to queue the evidence upload job
        appeal_submission_upload = AppealSubmissionUpload.find_or_create_by!(
          decision_review_evidence_attachment_guid: fa.guid,
          appeal_submission_id: appeal_submission.id
        )
        # This is the job that uploads the evidence to Lighthouse
        DecisionReview::SubmitUpload.perform_async(appeal_submission_upload.id)
      end
      # Return evidence upload job ids for logging
    end

    # Find Lighthouse NOD form submission records that were submitted to the new endpoint
    # NOD form submissions to this new endpoint were unaccompanied by evidence submissions
    # This code is intended to backfill those evidence submissions
    # 10/23/2023 is the date of toggling form submissions to new endpoint
    nods = AppealsApi::NoticeOfDisagreement.where(api_version: 'V2', board_review_option: 'evidence_submission')
                                           .where('created_at > ?', Date.new(2023, 10, 23))
    upload_job_ids = []

    nods.each do |nod| # Lighthouse NOD record
      jids = complete_nod_evidence_submissions(nod)
      upload_job_ids.concat(jids)
    rescue => e
      Rails.logger.error({
                           message: "Error while attempting to complete NOD evidence submission: #{e.message}",
                           appeals_api_nod_id: nod.id,
                           backtrace: e&.backtrace
                         })
    end
    Rails.logger.info({ message: 'Successfully enqueued evidence upload jobs', upload_job_ids: })
  end
end
