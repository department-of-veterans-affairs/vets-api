# frozen_string_literal: true

module AppealsApi::V1
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        skip_before_action :authenticate

        def show
          submissions = AppealsApi::EvidenceSubmission.where(
            supportable_id: params[:id],
            supportable_type: 'AppealsApi::NoticeOfDisagreement'
          )

          serialized = AppealsApi::EvidenceSubmissionSerializer.new(submissions)

          render json: serialized.serializable_hash
        end

        def create
          url = rewrite_url(signed_url(params[:uuid]))

          render json: { uuid: params[:uuid], url: url }
        end

        private

        def rewrite_url(url)
          rewritten = url.sub!(Settings.modules_appeals_api.evidence_submissions.location.prefix,
                               Settings.modules_appeals_api.evidence_submissions.location.replacement)
          raise 'Unable to provide document upload location' unless rewritten

          rewritten
        end

        def signed_url(uuid)
          s3 = Aws::S3::Resource.new(region: Settings.modules_appeals_api.s3.region,
                                     access_key_id: Settings.modules_appeals_api.s3.aws_access_key_id,
                                     secret_access_key: Settings.modules_appeals_api.s3.aws_secret_access_key)
          obj = s3.bucket(Settings.modules_appeals_api.s3.bucket).object(uuid)
          obj.presigned_url(:put, {})
        end
      end
    end
  end
end
