# frozen_string_literal: true

module V0
  class HcaDd214AttachmentsController < ApplicationController
    include FormAttachmentCreate

    FORM_ATTACHMENT_MODEL = HcaDd214Attachment
  end
end
