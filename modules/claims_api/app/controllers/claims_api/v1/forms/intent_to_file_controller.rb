# frozen_string_literal: true

require 'evss/intent_to_file/service'
require 'bgs_service/local_bgs'

module ClaimsApi
  module V1
    module Forms
      class IntentToFileController < ClaimsApi::V1::Forms::Base
        include ClaimsApi::PoaVerification

        before_action except: %i[schema] do
          permit_scopes %w[claim.write]
        end
        before_action :verify_power_of_attorney!, if: :header_request?
        skip_before_action :validate_veteran_identifiers, only: %i[submit_form_0966 validate]

        FORM_NUMBER = '0966'
        ITF_TYPES = %w[compensation pension burial].freeze

        # POST to submit intent to file claim.
        #
        # @return [JSON] Response from BGS
        def submit_form_0966
          ClaimsApi::Logger.log('itf', detail: '0966 - Request Started')
          validate_json_schema
          validate_veteran_identifiers(require_birls: true)
          check_for_invalid_burial_submission! if form_type == 'burial'
          ClaimsApi::Logger.log('itf', detail: '0966 - Controller Actions Completed')

          bgs_response = local_bgs_service.insert_intent_to_file(intent_to_file_options)
          if bgs_response.empty?
            ClaimsApi::IntentToFile.create!(status: ClaimsApi::IntentToFile::ERRORED, cid: token.payload['cid'])
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Veteran ID not found')
          else
            ClaimsApi::IntentToFile.create!(status: ClaimsApi::IntentToFile::SUBMITTED, cid: token.payload['cid'])
            ClaimsApi::Logger.log('itf', detail: 'Submitted to BGS')
            render json: bgs_response,
                   serializer: ClaimsApi::IntentToFileSerializer
          end
        end

        # GET current intent to file status based on type.
        #
        # @return [JSON] Response from BGS
        def active
          check_for_type
          bgs_response = local_bgs_service.find_intent_to_file_by_ptcpnt_id_itf_type_cd(
            target_veteran.participant_id,
            ClaimsApi::IntentToFile::ITF_TYPES_TO_BGS_TYPES[active_param]
          )
          if bgs_response.blank?
            message = "No Intent to file is on record for #{target_veteran_name} of type #{active_param}"
            raise ::Common::Exceptions::ResourceNotFound.new(detail: message)
          end

          bgs_active = if bgs_response.is_a?(Array)
                         bgs_response.detect { |itf| active?(itf) }
                       elsif active?(bgs_response)
                         bgs_response
                       end
          if bgs_active.blank?
            message = "No Intent to file is on record for #{target_veteran_name} of type #{active_param}"
            raise ::Common::Exceptions::ResourceNotFound.new(detail: message)
          end

          render json: bgs_active, serializer: ClaimsApi::IntentToFileSerializer
        end

        # POST to validate 0966 submission payload.
        #
        # @return [JSON] Success if valid, error messages if invalid.
        def validate
          ClaimsApi::Logger.log('itf', detail: '0966/validate - Request Started')
          add_deprecation_headers_to_response(response:, link: ClaimsApi::EndpointDeprecation::V1_DEV_DOCS)
          validate_json_schema
          validate_veteran_identifiers(require_birls: true)
          check_for_invalid_burial_submission! if form_type == 'burial'

          ClaimsApi::Logger.log('itf', detail: '0966/validate - Request Completed')
          render json: validation_success
        end

        private

        def intent_to_file_options
          options = {
            intent_to_file_type_code: ClaimsApi::IntentToFile::ITF_TYPES_TO_BGS_TYPES[form_type],
            participant_vet_id: form_attributes['participant_vet_id'] || target_veteran.participant_id,
            received_date: Time.zone.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
            submitter_application_icn_type_code: ClaimsApi::IntentToFile::SUBMITTER_CODE,
            ssn: target_veteran.ssn
          }

          handle_claimant_fields(options:, form_attributes:, target_veteran:)
        end

        # BGS requires at least 1 of 'participant_claimant_id' or 'claimant_ssn'
        def handle_claimant_fields(options:, form_attributes:, target_veteran:)
          claimant_ssn = form_attributes['claimant_ssn']
          participant_claimant_id = form_attributes['participant_claimant_id']

          options[:claimant_ssn] = claimant_ssn if claimant_ssn
          options[:participant_claimant_id] = participant_claimant_id if participant_claimant_id

          # if neither field was provided, then default to sending 'participant_claimant_id'
          if options[:claimant_ssn].blank? && options[:participant_claimant_id].blank?
            options[:participant_claimant_id] = target_veteran.participant_id
          end

          options
        end

        def active?(itf)
          itf.present? && itf[:itf_status_type_cd] == 'Active' && itf[:exprtn_dt].to_datetime > Time.zone.now
        end

        def active_param
          params.require(:type)
        end

        def check_for_type
          return unless active_param && ITF_TYPES.exclude?(active_param)

          message = "Must include either compensation, pension or burial as a 'type' parameter."
          raise ::Common::Exceptions::UnprocessableEntity.new(detail: message)
        end

        def form_type
          form_attributes['type']
        end

        def validation_success
          {
            data: {
              type: 'intentToFileValidation',
              attributes: {
                status: 'valid'
              }
            }
          }
        end

        def check_for_invalid_burial_submission!
          error_detail = "Veteran cannot file for type 'burial'"
          raise ::Common::Exceptions::Forbidden, detail: error_detail if veteran_submitting_burial_itf?

          error_detail = 'unknown claimaint id'
          raise ::Common::Exceptions::Forbidden, detail: error_detail unless request_includes_claimant_id?
        end

        def veteran_submitting_burial_itf?
          form_type == 'burial' && !header_request?
        end

        def request_includes_claimant_id?
          form_attributes['participant_claimant_id'].present? || form_attributes['claimant_ssn'].present?
        end
      end
    end
  end
end
