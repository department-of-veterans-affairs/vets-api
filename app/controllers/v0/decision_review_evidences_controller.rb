# frozen_string_literal: true

require 'decision_review_v1/utilities/logging_utils'

# Notice of Disagreement evidence submissions
module V0
  class DecisionReviewEvidencesController < ApplicationController
    include FormAttachmentCreate
    include DecisionReviewV1::Appeals::LoggingUtils
    service_tag 'evidence-upload'

    FORM_ATTACHMENT_MODEL = DecisionReviewEvidenceAttachment

    private

    # This method, declared in `FormAttachmentCreate`, is responsible for uploading file data to S3.
    def save_attachment_to_cloud!
      common_log_params = {
        key: :evidence_upload_to_s3,
        form_id: get_form_id_from_request_headers,
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

    def get_form_id_from_request_headers
      # 'Source-App-Name', which specifies the form from which evidence was submitted, is taken from `window.appName`,
      # which is taken from the `entryName` in the manifest.json files for each form. See:
      # - vets-website/src/platform/utilities/api/index.js (apiRequest)
      # - vets-website/src/platform/startup/setup.js (setUpCommonFunctionality)
      # - vets-website/src/platform/startup/index.js (startApp)
      source_app_name = request.headers['Source-App-Name']
      # The higher-level review form (996) is not included in this list because it does not permit evidence uploads.
      form_id = {
        '10182-board-appeal' => '10182',
        '995-supplemental-claim' => '995'
      }[source_app_name]

      if form_id.present?
        form_id
      else
        # If, for some odd reason, the `entryName`s are changed in these manifest.json files (or if the HLR form begins
        # accepting additional evidence), we will trigger a DataDog alert hinging on the StatsD metric below. Upon
        # receiving this alert, we can update the form_id hash above.
        StatsD.increment('decision_review.evidence_upload_to_s3.unexpected_form_id')
        # In this situation, there is no good reason to block the Veteran from uploading their evidence to S3,
        # so we return the unexpected `source_app_name` to be logged by `log_formatted` above.
        source_app_name
      end
    end
  end
end
