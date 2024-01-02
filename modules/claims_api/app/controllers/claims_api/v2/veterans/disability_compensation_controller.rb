# frozen_string_literal: true

require 'common/exceptions'
require 'jsonapi/parser'
require 'claims_api/v2/disability_compensation_validation'
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
        include ClaimsApi::V2::DisabilityCompensationValidation
        include ClaimsApi::V2::Error::LighthouseErrorHandler
        include ClaimsApi::V2::JsonFormatValidation

        FORM_NUMBER = '526'

        skip_before_action :validate_json_format, only: [:attachments]
        before_action :shared_validation, :file_number_check, only: %i[submit validate]

        def submit # rubocop:disable Metrics/MethodLength
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers:, form_data: form_attributes,
            flashes:,
            cid: token.payload['cid'], veteran_icn: target_veteran.mpi.icn,
            validation_method: ClaimsApi::AutoEstablishedClaim::VALIDATION_METHOD
          )
          # .create returns the resulting object whether the object was saved successfully to the database or not.
          # If it's lacking the ID, that means the create was unsuccessful and an identical claim already exists.
          # Find and return that claim instead.
          unless auto_claim.id
            existing_auto_claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: auto_claim.md5)
            auto_claim = existing_auto_claim if existing_auto_claim.present?
          end
          save_auto_claim!(auto_claim)

          if auto_claim.errors.present?
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(
              detail: auto_claim.errors.messages.to_s
            )
          end

          track_pact_counter auto_claim

          # This kicks off the first of three jobs required to fully establish the claim
          process_claim(auto_claim) unless Flipper.enabled? :claims_load_testing

          render json: ClaimsApi::V2::Blueprints::AutoEstablishedClaimBlueprint.render(
            auto_claim, root: :data
          ), status: :accepted, location: url_for(controller: 'claims', action: 'show', id: auto_claim.id)
        end

        def validate
          render json: valid_526_response
        end

        def attachments
          if params.keys.select { |key| key.include? 'attachment' }.count > 10
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(
              detail: 'Too many attachments.'
            )
          end

          claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(params[:id])

          unless claim
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
              detail: 'Resource not found'
            )
          end

          documents_service(params, claim).process_documents unless Flipper.enabled? :claims_load_testing

          render json: ClaimsApi::V2::Blueprints::AutoEstablishedClaimBlueprint.render(
            claim, root: :data
          ), status: :accepted, location: url_for(controller: 'claims', action: 'show', id: claim.id)
        end

        def generate_pdf
          # Returns filled out 526EZ form as PDF
          render json: { data: { attributes: {} } } # place holder
        end

        private

        def process_claim(auto_claim)
          ClaimsApi::V2::DisabilityCompensationPdfGenerator.perform_async(
            auto_claim.id,
            veteran_middle_initial # PDF mapper just needs middle initial
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

        def documents_service(params, claim)
          ClaimsApi::V2::DisabilityCompensationDocuments.new(params, claim)
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

          # Fetch the claim by md5 if it doesn't have an ID (given duplicate md5)
          if claim.id.nil? && claim.errors.find { |e| e.attribute == :md5 }&.type == :taken
            claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: claim.md5) || claim
          end
          if claim.id
            ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT',
                                              consumer_label: token.payload['label'] || token.payload['cid']
          end
        end

        def valid_pact_act_claim?
          form_attributes['disabilities'].any? do |d|
            d['isRelatedToToxicExposure'] && d['disabilityActionType'] == 'NEW'
          end
        end

        def save_auto_claim!(auto_claim)
          auto_claim.validation_method = ClaimsApi::AutoEstablishedClaim::VALIDATION_METHOD
          auto_claim.save!
        end
      end
    end
  end
end
