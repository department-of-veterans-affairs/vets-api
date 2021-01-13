# frozen_string_literal: true

class DeleteAttachmentJob
  include Sidekiq::Worker

  sidekiq_options(unique_for: 30.minutes, retry: false)

  EXPIRATION_TIME = 2.months

  def perform
    FormAttachment.where(
      'created_at < ?', EXPIRATION_TIME.ago
    ).where(
      type: self.class::ATTACHMENT_CLASSES
    ).where.not(guid: uuids_to_keep).find_each(&:destroy!)
  end

  def uuids_to_keep
    uuids = []

    InProgressForm.where(form_id: self.class::FORM_ID).find_each do |in_progress_form|
      uuids += get_uuids(in_progress_form.data_and_metadata[:formData])
    end

    uuids
  end
end
