# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::NoticeOfDisagreements::V0
  class NoticeOfDisagreementsController < AppealsApi::ApplicationController
    include AppealsApi::CharacterUtilities
    include AppealsApi::IcnParameterValidation
    include AppealsApi::JsonFormatValidation
    include AppealsApi::OpenidAuth
    include AppealsApi::PdfDownloads
    include AppealsApi::Schemas
    include AppealsApi::StatusSimulation

    skip_before_action :authenticate
    before_action :validate_json_body, if: -> { request.post? }
    before_action :validate_json_schema, only: %i[create validate]
    before_action :validate_icn_parameter, only: %i[download]

    ALLOWED_COLUMNS = %i[id status code detail created_at updated_at].freeze
    API_VERSION = 'V0'
    FORM_NUMBER = '10182'
    MODEL_ERROR_STATUS = 422
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

      render_notice_of_disagreement(nod, status: :created)
    end

    def download
      id = params[:id]
      notice_of_disagreement = AppealsApi::NoticeOfDisagreement.find(id)

      render_appeal_pdf_download(
        notice_of_disagreement,
        "#{FORM_NUMBER}-notice-of-disagreement-#{id}.pdf",
        params[:icn]
      )
    rescue ActiveRecord::RecordNotFound
      render_notice_of_disagreement_not_found(params[:id])
    end

    def validate
      render json: {
        data: {
          type: 'noticeOfDisagreementValidation',
          attributes: {
            status: 'valid'
          }
        }
      }
    end

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(form_schema)
    end

    private

    def validate_icn_parameter
      detail = nil

      if params[:icn].blank?
        detail = "'icn' parameter is required"
      elsif !ICN_REGEX.match?(params[:icn])
        detail = "'icn' parameter has an invalid format. Pattern: #{ICN_REGEX.inspect}"
      end

      raise Common::Exceptions::UnprocessableEntity.new(detail:) if detail.present?
    end

    def validate_json_schema
      validate_headers(request_headers)
      validate_form_data(@json_body)
    rescue Common::Exceptions::DetailedSchemaErrors => e
      render json: { errors: e.errors }, status: :unprocessable_entity
    end

    def render_notice_of_disagreement(nod, **)
      render(json: NoticeOfDisagreementSerializer.new(nod).serializable_hash, **)
    end

    def render_notice_of_disagreement_not_found(id)
      raise Common::Exceptions::ResourceNotFound.new(
        detail: I18n.t('appeals_api.errors.not_found', type: 'Notice of Disagreement', id:)
      )
    end

    def render_model_errors(nod)
      render json: model_errors_to_json_api(nod), status: MODEL_ERROR_STATUS
    end

    def header_names = headers_schema['definitions']['nodCreateParameters']['properties'].keys

    def request_headers
      header_names.index_with { |key| request.headers[key] }.compact
    end

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :notice_of_disagreements, :api_key)
    end
  end
end
