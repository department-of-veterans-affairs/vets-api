# frozen_string_literal: true

module Preneeds
  class DeleteOldUploads
    include Sidekiq::Worker

    sidekiq_options(unique_for: 30.minutes, retry: false)

    EXPIRATION_TIME = 2.months

    def perform
      VIC::TagSentry.tag_sentry

      Preneeds::PreneedAttachment.where(
        'created_at < ?', EXPIRATION_TIME.ago
      ).where.not(guid: uuids_to_keep).find_each(&:destroy!)
    end

    def uuids_to_keep
      uuids = []

      InProgressForm.where(form_id: '40-10007').find_each do |in_progress_form|
        attachments = in_progress_form.data_and_metadata[:form_data]['preneedAttachments']
        attachments.each do |attachment|
          uuids << attachment['confirmationCode']
        end if attachments.present?
      end

      uuids
    end
  end
end
