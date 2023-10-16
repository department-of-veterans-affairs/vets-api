# frozen_string_literal: true

# Notice of Disagreement evidence submissions
module V0
  class DecisionReviewEvidencesController < ApplicationController
    include FormAttachmentCreate
    FORM_ATTACHMENT_MODEL = DecisionReviewEvidenceAttachment
  end
end
