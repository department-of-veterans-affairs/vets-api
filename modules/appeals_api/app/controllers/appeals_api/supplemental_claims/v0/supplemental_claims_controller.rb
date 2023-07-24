# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::SupplementalClaims::V0
  class SupplementalClaimsController < AppealsApi::V2::DecisionReviews::SupplementalClaimsController
    include AppealsApi::OpenidAuth
    include AppealsApi::PdfDownloads

    before_action :validate_icn_header, only: %i[download]

    API_VERSION = 'V0'
    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'supplemental_claims' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/SupplementalClaims.read representative/SupplementalClaims.read system/SupplementalClaims.read],
      PUT: %w[veteran/SupplementalClaims.write representative/SupplementalClaims.write system/SupplementalClaims.read],
      POST: %w[veteran/SupplementalClaims.write representative/SupplementalClaims.write system/SupplementalClaims.read]
    }.freeze

    def create
      sc = AppealsApi::SupplementalClaim.new(
        auth_headers: request_headers,
        form_data: @json_body,
        source: request_headers['X-Consumer-Username'].presence&.strip,
        evidence_submission_indicated: evidence_submission_indicated?,
        api_version: self.class::API_VERSION,
        veteran_icn: @json_body.dig('data', 'attributes', 'veteran', 'icn')
      )

      return render_model_errors(sc) unless sc.validate

      sc.save
      AppealsApi::PdfSubmitJob.perform_async(sc.id, 'AppealsApi::SupplementalClaim', 'v3')

      render json: AppealsApi::SupplementalClaimSerializer.new(sc).serializable_hash
    end

    def download
      id = params[:id]
      supplemental_claim = AppealsApi::SupplementalClaim.find(id)

      render_appeal_pdf_download(supplemental_claim, "#{FORM_NUMBER}-supplemental-claim-#{id}.pdf")
    rescue ActiveRecord::RecordNotFound
      render_supplemental_claim_not_found(id)
    end

    private

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :supplemental_claims, :api_key)
    end
  end
end
