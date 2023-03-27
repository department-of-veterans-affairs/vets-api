# frozen_string_literal: true

require 'claims_api/v2/params_validation/intent_to_file'
require 'bgs_service/local_bgs'

module ClaimsApi
  module V2
    module Veterans
      class IntentToFileController < ClaimsApi::V2::ApplicationController
        before_action :verify_access!

        # GET to fetch active intent to file by type
        #
        # @return [JSON] ITF record
        def type
          validate_request!(ClaimsApi::V2::ParamsValidation::IntentToFile)

          type = get_bgs_type(params)
          response = bgs_service.intent_to_file.find_intent_to_file_by_ptcpnt_id_itf_type_cd(
            target_veteran.participant_id,
            type
          )

          response = [response] unless response.is_a?(Array)
          intent_to_files = response.compact.collect do |element|
            bgs_itf_to_lighthouse_itf(bgs_itf: element)
          end

          active_itf = intent_to_files.detect do |itf|
            itf[:status].casecmp?('active') && itf[:expiration_date].to_datetime > Time.zone.now
          end

          message = "No active '#{params[:type]}' intent to file found."
          raise ::Common::Exceptions::ResourceNotFound.new(detail: message) if active_itf.blank?

          render json: ClaimsApi::V2::Blueprints::IntentToFileBlueprint.render(active_itf, root: :data)
        end

        def submit
          validate_request!(ClaimsApi::V2::ParamsValidation::IntentToFile)
          type = get_bgs_type(params)
          options = build_options_and_validate(type)

          bgs_response = local_bgs_service.insert_intent_to_file(options)

          lighthouse_itf = bgs_itf_to_lighthouse_itf(bgs_itf: bgs_response)

          render json: ClaimsApi::V2::Blueprints::IntentToFileBlueprint.render(lighthouse_itf, root: :data)
        end

        def validate
          validate_request!(ClaimsApi::V2::ParamsValidation::IntentToFile)
          type = get_bgs_type(params)
          build_options_and_validate(type)
          render json: {
            data: {
              type: 'intent_to_file_validation',
              attributes: {
                status: 'valid'
              }
            }
          }
        end

        private

        def build_options_and_validate(type)
          options = build_intent_to_file_options(type)
          check_for_invalid_survivor_submission(options) if type == 'S'
          options
        end

        def build_intent_to_file_options(type)
          options = {
            intent_to_file_type_code: type,
            participant_vet_id: target_veteran.participant_id,
            received_date: Time.zone.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
            submitter_application_icn_type_code: ClaimsApi::IntentToFile::SUBMITTER_CODE,
            ssn: target_veteran.ssn
          }
          handle_claimant_fields(options: options, params: params, target_veteran: target_veteran)
        end

        # BGS requires at least 1 of 'participant_claimant_id' or 'claimant_ssn'
        def handle_claimant_fields(options:, params:, target_veteran:)
          claimant_ssn = params[:claimantSsn]
          if claimant_ssn.present?
            claimant_ssn = claimant_ssn.delete('^0-9')
            validate_ssn(claimant_ssn)
          end
          options[:claimant_ssn] = claimant_ssn if claimant_ssn

          # if claimant_ssn field was not provided, then default to sending 'participant_claimant_id'
          options[:participant_claimant_id] = target_veteran.participant_id if options[:claimant_ssn].blank?

          options
        end

        def validate_ssn(ssn)
          regex = /^(\d{9})$/
          unless regex.match?(ssn)
            error_detail = 'Invalid claimantSsn parameter'
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: error_detail)
          end
        end

        def check_for_invalid_survivor_submission(options)
          error_detail = "claimantSsn parameter cannot be blank for type 'survivor'"
          raise ::Common::Exceptions::UnprocessableEntity.new(detail: error_detail) if claimant_ssn_blank?(options)

          error_detail = "Veteran cannot file for type 'survivor'"
          if claimant_id_equals_vet_id?(options)
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: error_detail)
          end

          error_detail = "Claimant SSN cannot be the same as veteran SSN for type 'survivor'"
          if claimant_ssn_equals_vet_ssn?(options)
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: error_detail)
          end
        end

        def claimant_ssn_blank?(options)
          options[:claimant_ssn].blank?
        end

        def claimant_id_equals_vet_id?(options)
          options[:participant_claimant_id] == options[:participant_vet_id]
        end

        def claimant_ssn_equals_vet_ssn?(options)
          options[:claimant_ssn] == options[:ssn]
        end

        def get_bgs_type(params)
          itf_types[params[:type].downcase]
        end

        def itf_types
          ClaimsApi::V2::IntentToFile::ITF_TYPES_TO_BGS_TYPES
        end

        def bgs_itf_to_lighthouse_itf(bgs_itf:)
          {
            creation_date: bgs_itf[:create_dt],
            expiration_date: bgs_itf[:exprtn_dt],
            id: bgs_itf[:intent_to_file_id],
            status: bgs_itf[:itf_status_type_cd],
            type: bgs_itf[:itf_type_cd]
          }
        end
      end
    end
  end
end
