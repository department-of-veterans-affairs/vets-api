# frozen_string_literal: true

module V0
  module VIC
    class ProfilePhotoAttachmentsController < ApplicationController
      include FormAttachmentCreate

      FORM_ATTACHMENT_MODEL = ::VIC::ProfilePhotoAttachment
    end
  end
end
