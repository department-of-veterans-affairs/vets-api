# frozen_string_literal: true

module Preneeds
  class DeleteOldUploads
    include Sidekiq::Worker

    def perform
      VIC::TagSentry.tag_sentry

      uuids_to_keep = []

      InProgressForm.where(form_id: '40-10007').find_each do |in_progress_form|
        attachments = in_progress_form.data_and_metadata[:form_data]['preneedAttachments']
        attachments.each do |attachment|
          uuids_to_keep << attachment['confirmationCode']
        end if attachments.present?
      end
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

    def photos_to_keep
      guids = []
      ::InProgressForm.where(form_id: 'VIC').find_each do |ipf|
        photo = ipf.data_and_metadata[:form_data]['photo']
        guids << photo['confirmationCode'] if photo.present?
      end

      keep = []
      ::VIC::ProfilePhotoAttachment.where(guid: guids).find_each do |photo|
        keep << photo.get_file.path
      end

      keep
    end

    def docs_to_keep
      guids = []
      ::InProgressForm.where(form_id: 'VIC').find_each do |ipf|
        docs = ipf.data_and_metadata[:form_data]['dd214']
        docs.each { |doc| guids << doc['confirmationCode'] } if docs.present?
      end

      keep = []
      ::VIC::SupportingDocumentationAttachment.where(guid: guids).find_each do |doc|
        keep << doc.get_file.path
      end

      keep
    end

    private

    # :nocov:
    def delete_photos
      keep = photos_to_keep

      if Rails.env.production?
        bucket.objects.with_prefix('profile_photo_attachments').delete_if do |obj|
          obj.last_modified < 2.months.ago && keep.exclude?(obj.key)
        end
      end
    end

    def delete_docs
      keep = docs_to_keep

      if Rails.env.production?
        bucket.objects.with_prefix('supporting_documentation_attachments').delete_if do |obj|
          obj.last_modified < 2.months.ago && keep.exclude?(obj.key)
        end
      end
    end

    def bucket
      return @bucket if @bucket.present?

      client = Aws::S3::Client.new(
        access_key_id: Settings.vic.s3.aws_access_key_id,
        secret_access_key: Settings.vic.s3.aws_secret_access_key,
        region: Settings.vic.s3.region
      )
      s3 = Aws::S3::Resource.new(client: client)
      @bucket = s3.bucket(Settings.vic.s3.bucket)
      @bucket
    end
    # :nocov
  end
end
