# frozen_string_literal: true
module V0
  module VIC
    class GovtIdAttachmentsController < ApplicationController
      include FormAttachmentCreate

      FORM_ATTACHMENT_MODEL = ::VIC::GovtIdAttachment
    end
  end
end
