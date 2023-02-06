# frozen_string_literal: true

require 'evss/disability_compensation_form/service'
require 'evss/disability_compensation_form/dvp/service'
require 'evss/disability_compensation_form/service_exception'
require 'evss/error_middleware'
require 'evss/reference_data/service'
require 'common/exceptions'
require 'jsonapi/parser'

module ClaimsApi
  module V1
    module Forms
      class DisabilityCompensationController < ClaimsApi::V1::Forms::Base
        include ClaimsApi::DisabilityCompensationValidations
        include ClaimsApi::PoaVerification
        include ClaimsApi::DocumentValidations

        FORM_NUMBER = '526'
        STATSD_VALIDATION_FAIL_KEY = 'api.claims_api.526.validation_fail'
        STATSD_VALIDATION_FAIL_TYPE_KEY = 'api.claims_api.526.validation_fail_type'
        EVSS_DOCUMENT_TYPE = 'L023'

        before_action except: %i[schema] do
          permit_scopes %w[claim.write]
        end
        skip_before_action :validate_json_format, only: %i[upload_supporting_documents]
        before_action :verify_power_of_attorney!, if: :header_request?
        skip_before_action :validate_veteran_identifiers, only: %i[submit_form_526 validate_form_526]

        # POST to submit disability claim.
        #
        # @return [JSON] Record in pending state
        def submit_form_526 # rubocop:disable Metrics/MethodLength
          ClaimsApi::Logger.log('526', detail: '526 - Request Started')
          sanitize_account_type if form_attributes.dig('directDeposit', 'accountType')
          validate_json_schema
          validate_form_526_submission_values!
          validate_veteran_identifiers(require_birls: true)
          validate_initial_claim
          ClaimsApi::Logger.log('526', detail: '526 - Controller Actions Completed')

          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes,
            flashes: flashes,
            special_issues: special_issues_per_disability,
            source: source_name,
            cid: token.payload['cid'],
            veteran_icn: target_veteran.mpi.icn
          )

          ClaimsApi::Logger.log('526', claim_id: auto_claim.id, detail: 'Submitted to Lighthouse',
                                       pdf_gen_dis: form_attributes['autoCestPDFGenerationDisabled'])

          # .create returns the resulting object whether the object was saved successfully to the database or not.
          # If it's lacking the ID, that means the create was unsuccessful and an identical claim already exists.
          # Find and return that claim instead.
          unless auto_claim.id
            existing_auto_claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: auto_claim.md5)
            auto_claim = existing_auto_claim if existing_auto_claim.present?
          end

          if auto_claim.errors.present?
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: auto_claim.errors.messages.to_s)
          end

          unless form_attributes['autoCestPDFGenerationDisabled'] == true
            ClaimsApi::ClaimEstablisher.perform_async(auto_claim.id)
          end

          ClaimsApi::Logger.log('526', detail: '526 - Request Completed')
          render json: auto_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
        end

        # PUT to upload a wet-signed 526 form.
        # Required if first ever claim for Veteran.
        #
        # @return [JSON] Claim record
        def upload_form_526
          validate_document_provided
          validate_documents_content_type
          validate_documents_page_size

          pending_claim = ClaimsApi::AutoEstablishedClaim.pending?(params[:id])

          if pending_claim && (pending_claim.form_data['autoCestPDFGenerationDisabled'] == true)
            pending_claim.set_file_data!(documents.first, EVSS_DOCUMENT_TYPE)
            pending_claim.save!

            ClaimsApi::Logger.log('526', claim_id: pending_claim.id, detail: 'Uploaded PDF to S3')
            ClaimsApi::ClaimEstablisher.perform_async(pending_claim.id)
            ClaimsApi::ClaimUploader.perform_async(pending_claim.id)

            render json: pending_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
          elsif pending_claim && (pending_claim.form_data['autoCestPDFGenerationDisabled'] == false)
            message = <<-MESSAGE
              Claim submission requires that the "autoCestPDFGenerationDisabled" field
              must be set to "true" in order to allow a 526 PDF to be uploaded
            MESSAGE
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: message)
          else
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found')
          end
        end

        # POST to upload additional documents to support relevent disability compensation claim.
        #
        # @return [JSON] Claim record
        def upload_supporting_documents
          validate_documents_content_type
          validate_documents_page_size

          claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(params[:id])
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found') unless claim

          ClaimsApi::Logger.log(
            '526',
            claim_id: claim.id,
            detail: "/attachments called with #{documents.length} #{'attachment'.pluralize(documents.length)}"
          )

          documents.each do |document|
            claim_document = claim.supporting_documents.build
            claim_document.set_file_data!(document, EVSS_DOCUMENT_TYPE, params[:description])
            claim_document.save!
            ClaimsApi::ClaimUploader.perform_async(claim_document.id)
          end

          render json: claim, serializer: ClaimsApi::ClaimDetailSerializer, uuid: claim.id
        end

        # POST to validate 526 submission payload.
        #
        # @return [JSON] Success if valid, error messages if invalid.
        # rubocop:disable Metrics/MethodLength
        def validate_form_526
          ClaimsApi::Logger.log('526', detail: '526/validate - Request Started')
          add_deprecation_headers_to_response(response: response, link: ClaimsApi::EndpointDeprecation::V1_DEV_DOCS)
          sanitize_account_type if form_attributes.dig('directDeposit', 'accountType')
          validate_json_schema
          validate_form_526_submission_values!
          validate_veteran_identifiers(require_birls: true)
          validate_initial_claim
          ClaimsApi::Logger.log('526', detail: '526/validate - Controller Actions Completed')

          service =
            if Flipper.enabled? :form526_legacy
              EVSS::DisabilityCompensationForm::Service.new(auth_headers)
            else
              EVSS::DisabilityCompensationForm::Dvp::Service.new(auth_headers)
            end

          auto_claim = ClaimsApi::AutoEstablishedClaim.new(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes,
            flashes: flashes,
            special_issues: special_issues_per_disability
          )
          service.validate_form526(auto_claim.to_internal)
          ClaimsApi::Logger.log('526', detail: '526/validate - Request Completed')
          render json: valid_526_response
        rescue ::EVSS::DisabilityCompensationForm::ServiceException, EVSS::ErrorMiddleware::EVSSError => e
          error_details = e.is_a?(EVSS::ErrorMiddleware::EVSSError) ? e.details : e.messages
          track_526_validation_errors(error_details)
          raise ::Common::Exceptions::UnprocessableEntity.new(errors: format_526_errors(error_details))
        rescue ::Common::Exceptions::GatewayTimeout,
               ::Timeout::Error,
               ::Faraday::TimeoutError,
               Breakers::OutageException => e
          req = { auth: auth_headers, form: form_attributes, source: source_name, auto_claim: auto_claim.as_json }
          PersonalInformationLog.create(
            error_class: "validate_form_526 #{e.class.name}", data: { request: req, error: e.try(:as_json) || e }
          )
          raise e
        end
        # rubocop:enable Metrics/MethodLength

        private

        def sanitize_account_type
          form_attributes['directDeposit']['accountType'] = form_attributes['directDeposit']['accountType'].upcase
        end

        def flashes
          initial_flashes = form_attributes.dig('veteran', 'flashes') || []
          homelessness = form_attributes.dig('veteran', 'homelessness')
          is_terminally_ill = form_attributes.dig('veteran', 'isTerminallyIll')

          initial_flashes.push('Homeless') if homelessness.present?
          initial_flashes.push('Terminally Ill') if is_terminally_ill.present? && is_terminally_ill

          initial_flashes.present? ? initial_flashes.uniq : []
        end

        def special_issues_per_disability
          (form_attributes['disabilities'] || []).map { |disability| special_issues_for_disability(disability) }.compact
        end

        def special_issues_for_disability(disability)
          primary_special_issues = disability['specialIssues'] || []
          secondary_special_issues = []
          (disability['secondaryDisabilities'] || []).each do |secondary_disability|
            secondary_special_issues += (secondary_disability['specialIssues'] || [])
          end
          special_issues = primary_special_issues + secondary_special_issues

          # don't build a hash for disabilities that have no 'special_issues'
          return if special_issues.blank?

          mapper = ClaimsApi::SpecialIssueMappers::Bgs.new
          {
            code: disability['diagnosticCode'],
            name: disability['name'],
            special_issues: special_issues.map { |special_issue| mapper.code_from_name!(special_issue) }
          }
        end

        def validate_initial_claim
          if claims_service.claims_count.zero? && form_attributes['autoCestPDFGenerationDisabled'] == false
            message = 'Veteran has no claims, autoCestPDFGenerationDisabled requires true for Initial Claim'
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: message)
          end
        end

        def valid_526_response
          {
            data: {
              type: 'claims_api_auto_established_claim_validation',
              attributes: {
                status: 'valid'
              }
            }
          }.to_json
        end

        def format_526_errors(errors)
          errors.map do |error|
            { status: 422, detail: "#{error['key']} #{error['detail']}", source: error['key'] }
          end
        end

        def track_526_validation_errors(errors)
          StatsD.increment STATSD_VALIDATION_FAIL_KEY

          errors.each do |error|
            key = error['key']&.gsub(/\[(.*?)\]/, '')
            StatsD.increment STATSD_VALIDATION_FAIL_TYPE_KEY, tags: ["key: #{key}"]
          end
        end

        def unprocessable_response(e)
          log_message_to_sentry('Upload error in 526', :error, body: e.message)

          {
            errors: [{ status: 422, detail: e&.message, source: e&.key }]
          }.to_json
        end
      end
    end
  end
end
