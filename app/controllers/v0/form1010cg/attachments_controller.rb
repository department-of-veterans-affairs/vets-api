# frozen_string_literal: true

module V0
  module Form1010cg
    class AttachmentsController < ApplicationController
      include FormAttachmentCreate
      service_tag 'caregiver-application'

      skip_before_action :authenticate, raise: false

      FORM_ATTACHMENT_MODEL = ::Form1010cg::Attachment

      private

      def serializer_klass
        ::Form1010cg::AttachmentSerializer
      end
    end
  end
end
