# frozen_string_literal: true

module Preneeds
  # Models the actual attachments uploaded for a {Preneeds::BurialForm} form
  #
  class PreneedAttachment < FormAttachment
    # Set for parent class to use appropriate uploader
    #
    ATTACHMENT_UPLOADER_CLASS = PreneedAttachmentUploader
  end
end
