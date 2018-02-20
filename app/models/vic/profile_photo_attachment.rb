# frozen_string_literal: true

module VIC
  class ProfilePhotoAttachment < FormAttachment
    ATTACHMENT_UPLOADER_CLASS = ProfilePhotoAttachmentUploader

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
      uploader = VIC::ProcessingUploader.new(parsed_file_data['path'], parsed_file_data['filename'])
      uploader.retrieve_from_store!(uploader.filename)
      uploader.file
    end

    private

    def get_attachment_uploader(form_id)
      ProfilePhotoAttachmentUploader.new(SecureRandom.hex(32), form_id)
    end
  end
end
