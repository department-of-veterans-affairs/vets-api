# frozen_string_literal: true

module V0
  class Form1010EzrAttachmentsController < ApplicationController
    include FormAttachmentCreate
    service_tag 'health-information-update'

    FORM_ATTACHMENT_MODEL = Form1010EzrAttachment

    private

    def serializer_klass
      Form1010EzrAttachmentSerializer
    end
  end
end
