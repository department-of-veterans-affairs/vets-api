# frozen_string_literal: true

module V0
  class UploadSupportingEvidencesController < ApplicationController
    include FormAttachmentCreate

    service_tag 'disability-application'

    FORM_ATTACHMENT_MODEL = SupportingEvidenceAttachment

    private

    def serializer_klass
      SupportingEvidenceAttachmentSerializer
    end
  end
end
