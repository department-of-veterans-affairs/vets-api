# frozen_string_literal: true

module VIC
  class DeleteOldUploads
    include Sidekiq::Worker

    def perform
      keep_photos = photos_to_keep
      keep_docs = docs_to_keep

      if Rails.env.production?
        client = Aws::S3::Client.new(
          access_key_id: Settings.vic.s3.aws_access_key_id,
          secret_access_key: Settings.vic.s3.aws_secret_access_key,
          region: Settings.vic.s3.region
        )

        s3 = Aws::S3::Resource.new(client: client)
        bucket = s3.bucket(Settings.vic.s3.bucket)

        delete_docs(bucket, keep_photos)
        delete_photos(bucket, keep_docs)
      end
    end

    def delete_photos(bucket, keep)
      bucket.objects.with_prefix('profile_photo_attachments').delete_if do |obj|
        obj.last_modified < 2.months.ago && keep.exclude?(obj.key)
      end
    end

    def delete_docs(bucket, keep)
      bucket.objects.with_prefix('supporting_documentation_attachments').delete_if do |obj|
        obj.last_modified < 2.months.ago && keep.exclude?(obj.key)
      end
    end

    def vic_forms
      ::InProgressForm.where(form_id: 'VIC')
    end

    def photos_to_keep
      guids = []
      vic_forms.find_each do |ipf|
        form = ipf.data_and_metadata[:form_data]
        guids << form['photo']['confirmationCode']
      end

      keep = []
      ::VIC::ProfilePhotoAttachment.where(guid: guids).find_each do |photo|
        keep << photo.get_file.path
      end

      keep
    end

    def docs_to_keep
      guids = []
      vic_forms.find_each do |ipf|
        form = ipf.data_and_metadata[:form_data]
        guids << form['dd214']['confirmationCode']
      end

      keep = []
      ::VIC::SupportingDocumentationAttachment.where(guid: guids).find_each do |doc|
        keep << doc.get_file.path
      end

      keep
    end
  end
end
