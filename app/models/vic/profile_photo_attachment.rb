# frozen_string_literal: true

module VIC
  class ProfilePhotoAttachment < FormAttachment
    ATTACHMENT_UPLOADER_CLASS = ProfilePhotoAttachmentUploader

    def get_file
      uploader = VIC::ProcessingUploader.new(
        'profile_photo_attachments',
        parsed_file_data['filename']
      )
      uploader.retrieve_from_store!(uploader.filename)
      uploader.file
    end

    private

    def get_attachment_uploader
      ProfilePhotoAttachmentUploader.new(SecureRandom.hex(32))
    end
  end
end
