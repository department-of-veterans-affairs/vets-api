# frozen_string_literal: true

require 'common/exceptions'
require 'jsonapi/parser'
require 'claims_api/v2/disability_compensation_validation'
require 'claims_api/v2/alt_revised_disability_compensation_validation'
require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'claims_api/v2/disability_compensation_documents'
require 'evss_service/base'
require 'pdf_generator_service/pdf_client'
require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/json_format_validation'

module ClaimsApi
  module V2
    module Veterans
      class DisabilityCompensationController < ClaimsApi::V2::Veterans::Base
        # Commenting out the below validation inclusion so it is clearer that
        # we expect validate_form_526_submission_values! to be dynamically
        # included via the lighthouse_claims_api_v2_enable_FES FF check:
        # include ClaimsApi::V2::DisabilityCompensationValidation
        include ClaimsApi::V2::Error::LighthouseErrorHandler
        include ClaimsApi::V2::JsonFormatValidation

        FORM_NUMBER = '526'

        before_action :shared_validation, :file_number_check, only: %i[validate synchronous]
        before_action :edipi_check, only: %i[validate synchronous]

        before_action only: %i[generate_pdf] do
          permit_scopes(%w[system/526-pdf.override], actions: [:generate_pdf])
        end
        before_action only: %i[synchronous] do
          permit_scopes(%w[system/526.override], actions: [:synchronous])
        end

        def validate
          render json: valid_526_response
        end

        # Returns filled out 526EZ form as PDF
        def generate_pdf # rubocop:disable Metrics/MethodLength
          validate_json_schema('GENERATE_PDF_526')
          mapped_claim = generate_pdf_mapper_service(
            form_attributes,
            get_pdf_data_wrapper,
            auth_headers,
            veteran_middle_initial,
            Time.zone.now
          ).map_claim
          # Calling after target_veteran is created via auth_headers call above
          validate_veteran_name(false)
          pdf_string = generate_526_pdf(mapped_claim)
          if pdf_string.present?
            file_name = SecureRandom.hex.to_s
            Tempfile.create([file_name, '.pdf']) do |pdf|
              pdf.binmode # Set the file to binary mode
              pdf.write(pdf_string)
              pdf.rewind # after writing return to the start of the PDF

              send_data pdf.read, filename: file_name, type: 'application/pdf', disposition: 'inline'
              # Once this block closes the tempfile will delete
            end
          else
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(
              detail: 'Failed to generate PDF'
            )
          end
        end

        def synchronous
          auto_claim = shared_submit_methods

          unless claims_load_testing # || sandbox_request(request)
            generate_pdf_from_service!(auto_claim.id, veteran_middle_initial) unless mocking
            form526_establishment_service.upload(auto_claim.id)
            queue_flash_updater(auto_claim.flashes, auto_claim.id)
            start_bd_uploader_job(auto_claim) if auto_claim.status != errored_state_value
            auto_claim.reload
          end

          render json: ClaimsApi::V2::Blueprints::MetaBlueprint.render(
            auto_claim, async: false
          ), status: :accepted, location: url_for(controller: 'claims', action: 'show', id: auto_claim.id)
        end

        private

        def shared_submit_methods # rubocop:disable Metrics/MethodLength
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers:, form_data: form_attributes,
            transaction_id: claim_transaction_id,
            flashes:,
            cid: token&.payload&.[]('cid'), veteran_icn: target_veteran&.mpi&.icn,
            validation_method: ClaimsApi::AutoEstablishedClaim::VALIDATION_METHOD
          )

          if auto_claim.errors.present?
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(
              detail: auto_claim.errors.messages.to_s
            )
          end

          form_attributes['disabilities'].each do |disability|
            if disability['classificationCode'].present?
              ClaimsApi::Logger.log('526_classification_code',
                                    classification_code: disability['classificationCode'],
                                    cid: token.payload['cid'], version: 'v2')
            end
          end

          track_pact_counter auto_claim

          auto_claim
        end

        def generate_pdf_from_service!(auto_claim_id, veteran_middle_initial)
          claim_status = pdf_generation_service.generate(auto_claim_id, veteran_middle_initial)

          if claim_status == ClaimsApi::AutoEstablishedClaim::ERRORED
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(
              detail: 'Failed to generate PDF'
            )
          end
        end

        def generate_pdf_mapper_service(form_data, pdf_data_wrapper, auth_headers, middle_initial, created_at)
          ClaimsApi::V2::DisabilityCompensationPdfMapper.new(
            form_data, pdf_data_wrapper, auth_headers, middle_initial, created_at
          )
        end

        # Docker container wants data: but not attributes:
        def generate_526_pdf(mapped_data)
          pdf = get_pdf_data_wrapper
          pdf[:data] = mapped_data[:data][:attributes]
          client = PDFClient.new(pdf)
          client.generate_pdf
        end

        def get_pdf_data_wrapper
          { data: {} }
        end

        # Only value required by background jobs that is missing in headers is middle name
        def veteran_middle_initial
          target_veteran.middle_name&.first&.upcase || ''
        end

        def flashes
          veteran_flashes = []
          homelessness = form_attributes.dig('homeless', 'currentlyHomeless', 'homelessSituationOptions')
          hardship = form_attributes.dig('homeless', 'riskOfBecomingHomeless', 'livingSituationOptions')

          veteran_flashes.push('Homeless') if homelessness.present?
          veteran_flashes.push('Hardship') if hardship.present?

          veteran_flashes
        end

        def shared_validation
          # Custom validations for 526 submission, we must check this first
          # Choose the appropriate validator module based on FF status - using self.extend
          # so that if validator (instance) methods call other instance methods within the module
          # they all have access to the the same instance
          @claims_api_forms_validation_errors = if Flipper.enabled?(:lighthouse_claims_api_v2_enable_FES)
                                                  extend(ClaimsApi::V2::AltRevisedDisabilityCompensationValidation)
                                                  alt_rev_validate_form_526_submission_values(target_veteran)
                                                else
                                                  extend(ClaimsApi::V2::DisabilityCompensationValidation)
                                                  validate_form_526_submission_values(target_veteran)
                                                end
          # JSON validations for 526 submission, will combine with previously captured errors and raise
          validate_json_schema
          validate_veteran_name(true)
          # if we get here there were only validations file errors
          if @claims_api_forms_validation_errors.present?
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::JsonFormValidationError,
                  @claims_api_forms_validation_errors
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
          }
        end

        def track_pact_counter(claim)
          return unless valid_pact_act_claim?

          find_claim(claim)

          if claim.id
            ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT',
                                              consumer_label: token.payload['label'] || token.payload['cid']
          end
        end

        def valid_pact_act_claim?
          form_attributes&.dig('disabilities')&.any? do |d|
            d['isRelatedToToxicExposure'] && d['disabilityActionType'] == 'NEW'
          end
        end

        def save_auto_claim!(auto_claim)
          auto_claim.validation_method = ClaimsApi::AutoEstablishedClaim::VALIDATION_METHOD
          auto_claim.save!
        end

        def pdf_generation_service
          ClaimsApi::DisabilityCompensation::PdfGenerationService.new
        end

        def form526_establishment_service
          ClaimsApi::DisabilityCompensation::Form526EstablishmentService.new
        end

        def queue_flash_updater(flashes, auto_claim_id)
          return if flashes.blank?

          ClaimsApi::FlashUpdater.perform_async(flashes, auto_claim_id)
        end

        def start_bd_uploader_job(auto_claim)
          bd_service.perform_async(auto_claim.id)
        end

        def errored_state_value
          ClaimsApi::AutoEstablishedClaim::ERRORED
        end

        def bd_service
          ClaimsApi::DisabilityCompensationBenefitsDocumentsUploader
        end

        def sandbox_request(request)
          request.base_url == 'https://sandbox-api.va.gov'
        end

        def claims_load_testing
          Flipper.enabled? :claims_load_testing
        end

        def mocking
          Settings.claims_api.benefits_documents.use_mocks
        end

        def find_claim(claim)
          ClaimsApi::AutoEstablishedClaim.find_by(header_hash: claim.header_hash) || claim
        end
      end
    end
  end
end
