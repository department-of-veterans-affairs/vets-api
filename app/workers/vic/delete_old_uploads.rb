# frozen_string_literal: true

module VIC
  class DeleteOldUploads
    include Sidekiq::Worker

    def perform
      s3 = Aws::S3::Resource.new

      photo_guids = []
      keep_photo_files = []
      keep_doc_files = []

      ::InProgressForm.where(form_id: 'VIC').find_each do |ipf|
        form = ipf.data_and_metadata[:form_data]

        photo_guids << form['photo']['confirmationCode']
        doc_files << "#{form['dd214']['confirmationCode']}.processed"
      end

      ::VIC::ProfilePhotoAttachment.where(guid: photo_guids).find_each do |photo|
        file_data = photo.parsed_file_data
        id = File.join(file_data['path'], file_data['filename'])
        photo_files << "#{id}.processed"
      end

      if Rails.env.production?
        bucket = s3.bucket(Settings.vic.s3.bucket)
        delete_docs(bucket, keep_doc_files)
        delete_photos(bucket, keep_photo_files)
      end
    end

    private

    def delete_photos(bucket, keep_photo_files)
      bucket.objects.with_prefix('profile_photo_attachments').delete_if do |obj|
        filename = File.join(File.dirname(obj.key), File.basename(obj.key))
        obj.last_modified < 2.months.ago && keep_photo_files.exclude?(filename)
      end
    end

    def delete_docs(bucket, keep_doc_files)
      bucket.objects.with_prefix('supporting_documentation_attachments').delete_if do |obj|
        filename = File.basename(obj.key)
        obj.last_modified < 2.months.ago && keep_doc_files.exclude?(filename)
      end
    end
  end
end
