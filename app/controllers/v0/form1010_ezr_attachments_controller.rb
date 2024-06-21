# frozen_string_literal: true

module V0
  class Form1010EzrAttachmentsController < ApplicationController
    if Flipper.enabled?(:form1010_ezr_attachments_controller)
      include FormAttachmentCreate
      service_tag 'health-information-update'

      FORM_ATTACHMENT_MODEL = Form1010EzrAttachment
    end
  end
end
