# frozen_string_literal: true

module V0
  class HCAAttachmentsController < ApplicationController
    include FormAttachmentCreate

    skip_before_action(:authenticate, raise: false)

    FORM_ATTACHMENT_MODEL = HCAAttachment
  end
end
