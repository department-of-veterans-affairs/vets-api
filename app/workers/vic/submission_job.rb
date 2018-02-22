# frozen_string_literal: true

module VIC
  class SubmissionJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(vic_submission_id, form, user_uuid)
      Raven.tags_context(backend_service: :vic)

      @vic_submission_id = vic_submission_id
      parsed_form = JSON.parse(form)
      Raven.extra_context(parsed_form: parsed_form)
      user = user_uuid.present? ? User.find(user_uuid) : nil

      response = Service.new.submit(parsed_form, user)

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
      parsed_form['dd214'].each do |file|
        doc = VIC::SupportingDocumentationAttachment.find_by(guid: file['confirmationCode'])
        doc.destroy
      end

      parsed_form['photo'].tap do |file|
        profile_photo = VIC::ProfilePhotoAttachment.find_by(guid: file['confirmationCode'])
        profile_photo.destroy
      end
    end
  end
end
