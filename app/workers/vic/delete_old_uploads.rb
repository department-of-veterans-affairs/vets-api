# frozen_string_literal: true

module VIC
  class DeleteOldUploads
    include Sidekiq::Worker

    def perform
      s3 = Aws::S3::Resource.new

      doc_guids = []
      photo_guids = []
      photo_ids = []

      ::InProgressForm.where(form_id: 'VIC').find_each do |ipf|
        form = ipf.data_and_metadata[:form_data]

        doc_guids << form['dd214']['confirmationCode']
        photo_guids << form['photo']['confirmationCode']
      end

      ::ProfilePhotoAttachments.where(guid: photo_guids).find_each do |photo|
        file_data = photo.parsed_file_data
        photo_ids << File.join(file_data['path'], file_data['filename'])
      end

      if Rails.env.production?
        bucket = s3.bucket(Settings.vic.s3.bucket)
        delete_docs(bucket, docs_guids)
        delete_photos(bucket, photo_ids)
      end
    end

    private

    def delete_photos(bucket, keep)
      bucket.objects.with_prefix('profile_photo_attachments').delete_if do |obj|
        id = File.join(File.dirname(obj.key), File.basename(obj.key))
        obj.last_modified < 2.months.ago && keep.excludes?(id)
      end
    end

    def delete_docs(bucket, keep)
      bucket.objects.with_prefix('supporting_documentation_attachments').delete_if do |obj|
        guid = File.basename(obj.key)
        obj.last_modified < 2.months.ago && keep.exclude?(guid)
      end
    end
  end
end
