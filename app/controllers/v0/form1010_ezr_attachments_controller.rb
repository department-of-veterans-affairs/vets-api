# frozen_string_literal: true

module V0
  class Form1010EzrAttachmentsController < ApplicationController
    include FormAttachmentCreate
    service_tag 'health-information-update'

    FORM_ATTACHMENT_MODEL = Form1010EzrAttachment

    def create
      if Flipper.enabled?(:form1010_ezr_attachments_controller)
        super
      else
        raise AbstractController::ActionNotFound.new('The action \'create\' could not be found for V0::Form1010EzrAttachmentsController')
      end
    end
  end
end
