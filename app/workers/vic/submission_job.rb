# frozen_string_literal: true

module VIC
  class SubmissionJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(vic_submission_id, form, user_uuid, start_time = nil)
      Raven.tags_context(backend_service: :vic)
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

      delete_uploads(parsed_form)
    rescue StandardError
      submission.update_attributes!(state: 'failed')
      raise
    end

    def submission
      @submission ||= VICSubmission.find(@vic_submission_id)
    end

    private

    def delete_uploads(parsed_form)
      attachment_records = @vic_service.get_attachment_records(parsed_form)

      attachment_records[:supporting].each(&:destroy)

      attachment_records[:profile_photo].destroy
    end
  end
end
