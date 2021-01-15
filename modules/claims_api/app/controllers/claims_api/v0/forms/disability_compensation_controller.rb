# frozen_string_literal: true

require_dependency 'claims_api/base_disability_compensation_controller'
require 'jsonapi/parser'

module ClaimsApi
  module V0
    module Forms
      class DisabilityCompensationController < BaseDisabilityCompensationController
        include ClaimsApi::DocumentValidations

        FORM_NUMBER = '526'

        skip_before_action(:authenticate)
        before_action :validate_json_schema, only: %i[submit_form_526 validate_form_526]
        before_action :validate_documents_content_type, only: %i[upload_supporting_documents upload_form_526]
        before_action :validate_documents_page_size, only: %i[upload_supporting_documents upload_form_526]
        skip_before_action :validate_json_format, only: %i[upload_supporting_documents]

        def submit_form_526
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes,
            flashes: flashes,
            special_issues: special_issues_per_disability,
            source: source_name
          )
          unless auto_claim.id
            existing_auto_claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: auto_claim.md5, source: source_name)
            auto_claim = existing_auto_claim if existing_auto_claim.present?
          end

          if auto_claim.errors.present?
            raise Common::Exceptions::UnprocessableEntity.new(detail: auto_claim.errors.messages.to_s)
          end

          ClaimsApi::ClaimEstablisher.perform_async(auto_claim.id)

          render json: auto_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
        end

        def upload_form_526
          pending_claim = ClaimsApi::AutoEstablishedClaim.pending?(params[:id])

          if pending_claim && (pending_claim.form_data['autoCestPDFGenerationDisabled'] == true)
            pending_claim.set_file_data!(documents.first, params[:doc_type])
            pending_claim.save!

            ClaimsApi::ClaimUploader.perform_async(pending_claim.id)

            render json: pending_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
          elsif pending_claim && (pending_claim.form_data['autoCestPDFGenerationDisabled'] == false)
            # rubocop:disable Layout/LineLength
            render json: { status: 422, message: 'Claim submission requires that the "autoCestPDFGenerationDisabled" field must be set to "true" in order to allow a 526 PDF to be uploaded' }.to_json, status: :unprocessable_entity
            # rubocop:enable Layout/LineLength
          else
            render json: { status: 404, message: 'Claim not found' }.to_json, status: :not_found
          end
        rescue => e
          render json: unprocessable_response(e), status: :unprocessable_entity
        end

        def upload_supporting_documents
          claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(params[:id])
          documents.each do |document|
            claim_document = claim.supporting_documents.build
            claim_document.set_file_data!(document, params[:doc_type], params[:description])
            claim_document.save!
            ClaimsApi::ClaimUploader.perform_async(claim_document.id)
          end

          render json: claim, serializer: ClaimsApi::ClaimDetailSerializer
        end

        def validate_form_526
          super
        end
      end
    end
  end
end
