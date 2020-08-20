# frozen_string_literal: true

module V0
  class HCAAttachmentsController < ApplicationController
    include FormAttachmentCreate

    FORM_ATTACHMENT_MODEL = HCAAttachment
  end
end
