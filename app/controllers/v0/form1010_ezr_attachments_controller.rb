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
        raise Common::Exceptions::InternalServerError, ArgumentError.new(
          "The 'create' route for V0::Form1010EzrAttachmentsController is currently unavailable"
        )
      end
    end
  end
end
