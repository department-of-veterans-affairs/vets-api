# frozen_string_literal: true

module V0
  class HCAAttachmentsController < ApplicationController
    include FormAttachmentCreate
    service_tag 'healthcare-application'

    skip_before_action(:authenticate, raise: false)

    FORM_ATTACHMENT_MODEL = HCAAttachment

    private

    def serializer_klass
      HCAAttachmentSerializer
    end
  end
end
