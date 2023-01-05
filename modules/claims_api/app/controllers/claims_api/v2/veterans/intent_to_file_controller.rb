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
          type = params[:type].downcase
          unless itf_types.keys.include?(type)
            message = "Invalid type parameter: '#{type}'"
            raise ::Common::Exceptions::ResourceNotFound.new(detail: message)
          end
          response = bgs_service.intent_to_file.find_intent_to_file_by_ptcpnt_id_itf_type_cd(
            target_veteran.participant_id,
            itf_types[type]
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

          type = ClaimsApi::IntentToFile::ITF_TYPES_TO_BGS_TYPES[params[:type].downcase]
          participant_claimant_id = params[:participant_claimant_id] || target_veteran.participant_id
          participant_vet_id = params[:participant_vet_id] || target_veteran.participant_id

          bgs_response = bgs_service.intent_to_file.insert_intent_to_file(
            intent_to_file_type_code: type,
            participant_claimant_id: participant_claimant_id,
            participant_vet_id: participant_vet_id,
            received_date: Time.zone.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
            submitter_application_icn_type_code: ClaimsApi::IntentToFile::SUBMITTER_CODE
          )

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
