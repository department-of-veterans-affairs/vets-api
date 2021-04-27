# frozen_string_literal: true

module Form1010cg
  class Attachment < FormAttachment
    ATTACHMENT_UPLOADER_CLASS = ::Form1010cg::PoaUploader
  end
end
