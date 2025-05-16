# frozen_string_literal: true

class PersistentAttachments::VAFormAttachment < PersistentAttachment
  include ::FormUpload::Uploader::Attachment.new(:file)

  before_destroy(:delete_file)

  private

  def delete_file
    file.delete
  end
end
