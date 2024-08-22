# frozen_string_literal: true

require 'logging/third_party_transaction'

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
