# frozen_string_literal: true

module VIC
  class ProfilePhotoAttachment < FormAttachment
    ATTACHMENT_UPLOADER_CLASS = ProfilePhotoAttachmentUploader

    after_create(:process_file)

    def set_file_data!(file, in_progress_form)
      attachment_uploader = get_attachment_uploader(in_progress_form&.id)
      attachment_uploader.store!(file)

      file_data = {
        filename: attachment_uploader.filename,
        path: attachment_uploader.store_dir,
        form_id: in_progress_form&.id,
        user_uuid: in_progress_form&.user_uuid
      }.compact

      self.file_data = file_data.to_json
    end

    def get_file
      process_file_uploader = ProcessFileUploader.new(parsed_file_data['path'])
      filename = ProcessFileUploader.get_new_filename(parsed_file_data['filename'])
      process_file_uploader.retrieve_from_store!(filename)
      process_file_uploader.file
    end

    private

    def process_file
      ProcessFileJob.perform_async(parsed_file_data['path'], parsed_file_data['filename'])
    end

    def get_attachment_uploader(form_id)
      ProfilePhotoAttachmentUploader.new(SecureRandom.hex(32), form_id)
    end
  end
end
