# frozen_string_literal: true

require 'claims_api/v2/params_validation/intent_to_file'

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

          type = itf_types[params[:type].downcase]
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

          render json: ClaimsApi::V2::Blueprints::IntentToFileBlueprint.render(active_itf)
        end

        def submit
          validate_request!(ClaimsApi::V2::ParamsValidation::IntentToFile)

          type = itf_types[params[:type].downcase]
          options = intent_to_file_options(type)
          check_for_invalid_survivor_submission(options) if type == 'S'
          bgs_response = bgs_service.intent_to_file.insert_intent_to_file(options)

          lighthouse_itf = bgs_itf_to_lighthouse_itf(bgs_itf: bgs_response)

          render json: ClaimsApi::V2::Blueprints::IntentToFileBlueprint.render(lighthouse_itf)
        end

        def validate
          validate_request!(ClaimsApi::V2::ParamsValidation::IntentToFile)
          render json: {
            data: {
              type: 'intentToFileValidation',
              attributes: {
                status: 'valid'
              }
            }
          }
        end

        private

        def intent_to_file_options(type)
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
          participant_claimant_id = params[:participantClaimantId]

          options[:claimant_ssn] = claimant_ssn if claimant_ssn
          options[:participant_claimant_id] = participant_claimant_id if participant_claimant_id

          # if neither field was provided, then default to sending 'participant_claimant_id'
          if options[:claimant_ssn].blank? && options[:participant_claimant_id].blank?
            options[:participant_claimant_id] = target_veteran.participant_id
          end

          options
        end

        def check_for_invalid_survivor_submission(options)
          error_detail = "Veteran cannot file for type 'survivor'"
          raise ::Common::Exceptions::Forbidden, detail: error_detail if claimant_id_equals_vet_id?(options)

          error_detail = 'unknown claimant id'
          raise ::Common::Exceptions::Forbidden, detail: error_detail unless options_include_claimant_id?(options)
        end

        def claimant_id_equals_vet_id?(options)
          options[:participant_claimant_id] == options[:participant_vet_id]
        end

        def options_include_claimant_id?(options)
          options[:participant_claimant_id].present? || options[:claimant_ssn].present?
        end

        def itf_types
          ClaimsApi::V2::IntentToFile::ITF_TYPES_TO_BGS_TYPES
        end

        def bgs_service
          BGS::Services.new(external_uid: target_veteran.participant_id,
                            external_key: target_veteran.participant_id)
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
