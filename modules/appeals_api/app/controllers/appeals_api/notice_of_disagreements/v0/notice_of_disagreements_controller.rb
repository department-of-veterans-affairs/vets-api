# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::NoticeOfDisagreements::V0
  class NoticeOfDisagreementsController < AppealsApi::V2::DecisionReviews::NoticeOfDisagreementsController
    include AppealsApi::OpenidAuth
    include AppealsApi::PdfDownloads

    before_action :validate_icn_header, only: %i[download]

    API_VERSION = 'V0'
    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'notice_of_disagreements' }.freeze

    OAUTH_SCOPES = {
      GET: %w[
        veteran/NoticeOfDisagreements.read
        representative/NoticeOfDisagreements.read
        system/NoticeOfDisagreements.read
      ],
      PUT: %w[
        veteran/NoticeOfDisagreements.write
        representative/NoticeOfDisagreements.write
        system/NoticeOfDisagreements.write
      ],
      POST: %w[
        veteran/NoticeOfDisagreements.write
        representative/NoticeOfDisagreements.write
        system/NoticeOfDisagreements.write
      ]
    }.freeze

    def download
      @id = params[:id]
      @notice_of_disagreement = AppealsApi::NoticeOfDisagreement.find(@id)

      render_appeal_pdf_download(@notice_of_disagreement, "#{FORM_NUMBER}-notice-of-disagreement-#{@id}.pdf")
    rescue ActiveRecord::RecordNotFound
      render_notice_of_disagreement_not_found
    end

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(form_schema)
    end

    private

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :notice_of_disagreements, :api_key)
    end
  end
end
