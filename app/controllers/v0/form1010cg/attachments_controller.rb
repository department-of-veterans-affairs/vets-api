# frozen_string_literal: true

module V0
  module Form1010cg
    class AttachmentsController < ApplicationController
      include FormAttachmentCreate

      skip_before_action :authenticate, raise: false

      FORM_ATTACHMENT_MODEL       = ::Form1010cg::Attachment
      FORM_ATTACHMENT_SERIALIZER  = ::Form1010cg::AttachmentSerializer
    end
  end
end
