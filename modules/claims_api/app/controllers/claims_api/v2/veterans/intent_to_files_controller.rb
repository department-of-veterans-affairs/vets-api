# frozen_string_literal: true

require 'claims_api/v2/params_validation/intent_to_file'

module ClaimsApi
  module V2
    module Veterans
      class IntentToFilesController < ClaimsApi::V2::ApplicationController
        before_action :verify_access!

        ITF_TYPES = %w[compensation pension burial].freeze

        def type
          response = bgs_service.intent_to_file.find_intent_to_file_by_ptcpnt_id_itf_type_cd(
            target_veteran.participant_id,
            ClaimsApi::IntentToFile::ITF_TYPES_TO_BGS_TYPES[params[:type]]
          )

          response = [response] unless response.is_a?(Array)
          intent_to_files = response.compact.collect do |element|
            bgs_itf_to_lighthouse_itf(bgs_itf: element)
          end

          active_itf = intent_to_files.detect(&:active?)

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

        private

        def bgs_service
          BGS::Services.new(external_uid: target_veteran.participant_id,
                            external_key: target_veteran.participant_id)
        end

        def bgs_itf_to_lighthouse_itf(bgs_itf:)
          attributes = {
            id: bgs_itf[:intent_to_file_id],
            creation_date: bgs_itf[:create_dt],
            expiration_date: bgs_itf[:exprtn_dt],
            status: bgs_itf[:itf_status_type_cd],
            type: bgs_itf[:itf_type_cd]
          }
          IntentToFile.new(attributes)
        end
      end
    end
  end
end
