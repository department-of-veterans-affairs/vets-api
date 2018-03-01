# frozen_string_literal: true

module VIC
  class SubmissionJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(vic_submission_id, form, user_uuid, start_time = nil)
      VIC::TagSentry.tag_sentry
      @vic_submission_id = vic_submission_id
      start_time ||= Time.zone.now.to_s

      @vic_service = Service.new
      parsed_form = JSON.parse(form)
      Raven.extra_context(parsed_form: parsed_form)

      unless @vic_service.wait_for_processed(parsed_form, start_time)
        return self.class.perform_async(vic_submission_id, form, user_uuid, start_time)
      end

      user = user_uuid.present? ? User.find(user_uuid) : nil
      response = @vic_service.submit(parsed_form, user)

      submission.update_attributes!(
        response: response
      )

      AttachmentUploadJob.perform_async(response[:case_id], form)
    rescue StandardError
      submission.update_attributes!(state: 'failed')
      raise
    end

    def submission
      @submission ||= VICSubmission.find(@vic_submission_id)
    end
  end
end
