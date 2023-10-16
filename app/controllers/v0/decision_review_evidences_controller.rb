# frozen_string_literal: true

require 'decision_review_v1/utilities/logging_utils'

# Notice of Disagreement evidence submissions
module V0
  class DecisionReviewEvidencesController < ApplicationController
    include FormAttachmentCreate
    include DecisionReviewV1::Appeals::LoggingUtils

    FORM_ATTACHMENT_MODEL = DecisionReviewEvidenceAttachment

    private

    # This method, declared in `FormAttachmentCreate`, is responsible for uploading file data to S3.
    def save_attachment_to_cloud!
      common_log_params = {
        key: :evidence_upload_to_s3,
        # Will have to update this when NOD and SC using same LH API version. The beginning of that work is ticketed in
        # https://github.com/department-of-veterans-affairs/va.gov-team/issues/66514.
        form_id: '10182',
        user_uuid: current_user.uuid,
        downstream_system: 'AWS S3',
        params: {
          # `form_attachment` is declared in `FormAttachmentCreate`, included above.
          form_attachment_guid: form_attachment&.guid
        }
      }
      super
      log_formatted(**common_log_params.merge(is_success: true))
    rescue => e
      log_formatted(**common_log_params.merge(is_success: false, response_error: e))
      raise e
    end
  end
end
