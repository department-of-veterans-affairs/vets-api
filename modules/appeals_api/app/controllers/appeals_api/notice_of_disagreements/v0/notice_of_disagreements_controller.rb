# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::NoticeOfDisagreements::V0
  class NoticeOfDisagreementsController < AppealsApi::V2::DecisionReviews::NoticeOfDisagreementsController
    include AppealsApi::OpenidAuth
    include AppealsApi::PdfDownloads

    skip_before_action :new_notice_of_disagreement
    skip_before_action :find_notice_of_disagreement

    before_action :validate_icn_parameter, only: %i[download]

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

    def show
      nod = AppealsApi::NoticeOfDisagreement.select(ALLOWED_COLUMNS).find(params[:id])
      nod = with_status_simulation(nod) if status_requested_and_allowed?

      render_notice_of_disagreement(nod)
    rescue ActiveRecord::RecordNotFound
      render_notice_of_disagreement_not_found(params[:id])
    end

    def create
      nod = AppealsApi::NoticeOfDisagreement.new(
        auth_headers: request_headers,
        form_data: @json_body,
        source: request_headers['X-Consumer-Username'].presence&.strip,
        board_review_option: @json_body.dig('data', 'attributes', 'boardReviewOption'),
        api_version: self.class::API_VERSION,
        veteran_icn: @json_body.dig('data', 'attributes', 'veteran', 'icn')
      )

      return render_model_errors(nod) unless nod.validate

      nod.save
      AppealsApi::PdfSubmitJob.perform_async(nod.id, 'AppealsApi::NoticeOfDisagreement', 'v3')

      render_notice_of_disagreement(nod)
    end

    def download
      id = params[:id]
      notice_of_disagreement = AppealsApi::NoticeOfDisagreement.find(id)

      render_appeal_pdf_download(notice_of_disagreement, "#{FORM_NUMBER}-notice-of-disagreement-#{id}.pdf")
    rescue ActiveRecord::RecordNotFound
      render_notice_of_disagreement_not_found(params[:id])
    end

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(form_schema)
    end

    private

    def validate_icn_parameter
      validation_errors = []

      if params[:icn].blank?
        validation_errors << { status: 422, detail: "'icn' parameter is required" }
      elsif !ICN_REGEX.match?(params[:icn])
        validation_errors << { status: 422,
                               detail: "'icn' parameter has an invalid format. Pattern: #{ICN_REGEX.inspect}" }
      end

      render json: { errors: validation_errors }, status: :unprocessable_entity if validation_errors.present?
    end

    def render_notice_of_disagreement(nod)
      render json: AppealsApi::NoticeOfDisagreementSerializer.new(nod).serializable_hash
    end

    def render_notice_of_disagreement_not_found(id)
      render(
        status: :not_found,
        json: {
          errors: [
            {
              code: '404',
              detail: I18n.t('appeals_api.errors.not_found', type: 'NoticeOfDisagreement', id:),
              status: '404',
              title: 'Record not found'
            }
          ]
        }
      )
    end

    def render_model_errors(nod)
      render json: model_errors_to_json_api(nod), status: MODEL_ERROR_STATUS
    end

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :notice_of_disagreements, :api_key)
    end
  end
end
