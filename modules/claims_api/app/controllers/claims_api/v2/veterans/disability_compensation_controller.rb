# frozen_string_literal: true

require 'common/exceptions'
require 'jsonapi/parser'
require 'claims_api/v2/disability_compensation_validation'
require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'evss_service/base'
require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module V2
    module Veterans
      class DisabilityCompensationController < ClaimsApi::V2::Veterans::Base
        include ClaimsApi::V2::DisabilityCompensationValidation

        FORM_NUMBER = '526'
        EVSS_DOCUMENT_TYPE = 'L023'

        before_action :shared_validation, :file_number_check, only: %i[submit validate]

        def submit # rubocop:disable Metrics/MethodLength
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers:,
            form_data: form_attributes,
            flashes:,
            cid: token.payload['cid'],
            veteran_icn: target_veteran.mpi.icn,
            validation_method: ClaimsApi::AutoEstablishedClaim::VALIDATION_METHOD
          )

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

          track_pact_counter auto_claim
          pdf_data = get_pdf_data
          pdf_mapper_service(form_attributes, pdf_data, target_veteran).map_claim

          if auto_claim.evss_id.nil?
            ClaimsApi::Logger.log('526_v2', claim_id: auto_claim.id, detail: 'Mapping EVSS Data')
            evss_data = evss_mapper_service(auto_claim).map_claim
            ClaimsApi::Logger.log('526_v2', claim_id: auto_claim.id, detail: 'Submitting to EVSS')
            evss_res = evss_service.submit(auto_claim, evss_data)
            ClaimsApi::Logger.log('526_v2', claim_id: auto_claim.id, detail: 'Successfully submitted to EVSS',
                                            evss_id: evss_res[:claimId])
            auto_claim.update(evss_id: evss_res[:claimId],
                              validation_method: ClaimsApi::AutoEstablishedClaim::VALIDATION_METHOD)
          else
            ClaimsApi::Logger.log('526_v2', claim_id: auto_claim.id, detail: 'EVSS Skipped',
                                            evss_id: auto_claim.evss_id)
          end

          ClaimsApi::Logger.log('526_v2', claim_id: auto_claim.id, detail: 'Starting call to 526EZ PDF generator')
          pdf_string = generate_526_pdf(pdf_data)
          ClaimsApi::Logger.log('526_v2', claim_id: auto_claim.id, detail: 'Completed call to 526EZ PDF generator')
          if pdf_string.empty?
            ClaimsApi::Logger.log('526_v2', claim_id: auto_claim.id, detail: '526EZ PDF generator failed.')
          elsif pdf_string
            file_name = "#{SecureRandom.hex}.pdf"
            path = ::Common::FileHelpers.generate_temp_file(pdf_string, file_name)
            upload = ActionDispatch::Http::UploadedFile.new({
                                                              filename: file_name,
                                                              type: 'application/pdf',
                                                              tempfile: File.open(path)
                                                            })
            auto_claim.set_file_data!(upload, EVSS_DOCUMENT_TYPE)
            auto_claim.validation_method = ClaimsApi::AutoEstablishedClaim::VALIDATION_METHOD
            auto_claim.save!
            ClaimsApi::Logger.log('526_v2', claim_id: auto_claim.id, detail: 'Uploaded 526EZ PDF to S3')
            ::Common::FileHelpers.delete_file_if_exists(path)
            ClaimsApi::ClaimUploader.perform_async(auto_claim.id)
            ClaimsApi::Logger.log('526_v2', claim_id: auto_claim.id, detail: 'Uploaded 526EZ PDF to VBMS')
          end
          get_benefits_documents_auth_token unless Rails.env.test?

          render json: auto_claim, status: :accepted, location: "#{request.url[0..-4]}claims/#{auto_claim.id}"
        end

        def validate
          render json: valid_526_response
        end

        def attachments; end

        def get_pdf
          # Returns filled out 526EZ form as PDF
        end

        private

        def flashes
          veteran_flashes = []
          homelessness = form_attributes.dig('homeless', 'currentlyHomeless', 'homelessSituationOptions')
          hardship = form_attributes.dig('homeless', 'riskOfBecomingHomeless', 'livingSituationOptions')

          veteran_flashes.push('Homeless') if homelessness.present?
          veteran_flashes.push('Hardship') if hardship.present?

          veteran_flashes
        end

        def shared_validation
          validate_json_schema
          validate_form_526_submission_values!(target_veteran)
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

        def generate_526_pdf(pdf_data)
          pdf_data[:data] = pdf_data[:data][:attributes]
          client = PDFClient.new(pdf_data.to_json)
          client.generate_pdf
        end

        def pdf_mapper_service(auto_claim, pdf_data, target_veteran)
          ClaimsApi::V2::DisabilityCompensationPdfMapper.new(auto_claim, pdf_data, target_veteran)
        end

        def evss_mapper_service(auto_claim)
          ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim, @file_number)
        end

        def track_pact_counter(claim)
          return unless form_attributes['disabilities']&.map { |d| d['isRelatedToToxicExposure'] }&.include? true

          # Fetch the claim by md5 if it doesn't have an ID (given duplicate md5)
          if claim.id.nil? && claim.errors.find { |e| e.attribute == :md5 }&.type == :taken
            claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: claim.md5) || claim
          end
          if claim.id
            ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT',
                                              consumer_label: token.payload['label'] || token.payload['cid']
          end
        end

        def evss_service
          ClaimsApi::EVSSService::Base.new(request)
        end

        def get_pdf_data
          {
            data: {}
          }
        end

        def benefits_doc_api
          ClaimsApi::BD.new
        end
      end
    end
  end
end
