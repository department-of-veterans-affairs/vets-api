# frozen_string_literal: true

module VIC
  class ProfilePhotoAttachment < FormAttachment
    ATTACHMENT_UPLOADER_CLASS = ProfilePhotoAttachmentUploader

    def set_file_data!(file, in_progress_form)
      attachment_uploader = get_attachment_uploader(in_progress_form)
      attachment_uploader.store!(file)

      file_data = {
        filename: attachment_uploader.filename,
        path: attachment_uploader.store_dir,
        user_uuid: in_progress_form&.user_uuid
      }.compact

      self.file_data = file_data.to_json
    end

    def get_file(in_progress_form)
      attachment_uploader = get_attachment_uploader(in_progress_form)

      attachment_uploader.retrieve_from_store!(
        parsed_file_data['filename']
      )
      attachment_uploader.file
    end

    private

    def get_attachment_uploader(in_progress_form)
      ProfilePhotoAttachmentUploader.new(SecureRandom.hex(32), in_progress_form)
    end
  end
end
