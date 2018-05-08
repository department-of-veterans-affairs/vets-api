# frozen_string_literal: true

module V0
  class UploadAncillaryFormsController < ApplicationController
    include FormAttachmentCreate
    FORM_ATTACHMENT_MODEL = AncillaryFormAttachment 
  end
end

