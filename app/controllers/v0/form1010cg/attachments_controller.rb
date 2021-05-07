# frozen_string_literal: true

module V0
  module Form1010cg
    class AttachmentsController < ApplicationController
      include FormAttachmentCreate

      skip_before_action :authenticate, raise: false
      skip_before_action :verify_authenticity_token

      FORM_ATTACHMENT_MODEL = ::Form1010cg::Attachment
    end
  end
end
