# frozen_string_literal: true

module V0
  module VIC
    class SupportingDocumentationAttachmentsController < BaseController
      include FormAttachmentCreate

      FORM_ATTACHMENT_MODEL = ::VIC::SupportingDocumentationAttachment
    end
  end
end
