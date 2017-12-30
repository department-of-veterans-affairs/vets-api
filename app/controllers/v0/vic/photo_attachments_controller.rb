# frozen_string_literal: true
module V0
  module VIC
    class PhotoAttachmentsController < ApplicationController
      include FormAttachmentCreate

      FORM_ATTACHMENT_MODEL = ::VIC::PhotoAttachment
    end
  end
end
