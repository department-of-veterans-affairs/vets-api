# frozen_string_literal: true

module V0
  module Preneeds
    class PreneedAttachmentsController < PreneedsController
      include FormAttachmentCreate

      FORM_ATTACHMENT_MODEL = ::Preneeds::PreneedAttachment
    end
  end
end
