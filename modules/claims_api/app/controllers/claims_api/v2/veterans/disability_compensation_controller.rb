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
        # EVSS_DOCUMENT_TYPE = 'L023'

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

          # Test fix
          auth_headers = auto_claim.auth_headers
          auth_headers['va_eauth_birlsfilenumber'] = auth_headers['va_eauth_pnid']
          auto_claim.auth_headers = auth_headers
          auto_claim.save!
          # End test fix

          # This kicks off the first of three jobs required to fully establish the claim
          process_claim(auto_claim)

          # Is this even needed here anymore ???
          # get_benefits_documents_auth_token unless Rails.env.test?

          render json: auto_claim
        end

        def validate
          render json: valid_526_response
        end

        def attachments; end

        def get_pdf
          # Returns filled out 526EZ form as PDF
        end

        private

        def process_claim(auto_claim)
          ClaimsApi::V2::DisabilityCompensationPdfGenerator.perform_async(
            auto_claim.id,
            veteran_middle_initial, # PDF mapper just needs middle initial
            @file_number # EVSS mapper needs this number
          )
        end

        # Only value required by background jobs that is missing in headers is middle name
        def veteran_middle_initial
          @target_veteran.middle_name ? @target_veteran.middle_name[0].uppercase : ''
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
      end
    end
  end
end
