# frozen_string_literal: true

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
            attributes = {
              id: element[:intent_to_file_id],
              creation_date: element[:create_dt],
              expiration_date: element[:exprtn_dt],
              status: element[:itf_status_type_cd],
              type: element[:itf_type_cd]
            }
            IntentToFile.new(attributes)
          end

          active_itf = intent_to_files.detect(&:active?)

          message = "No active '#{params[:type]}' intent to file found."
          raise ::Common::Exceptions::ResourceNotFound.new(detail: message) if active_itf.blank?

          render json: ClaimsApi::V2::Blueprints::IntentToFileBlueprint.render(active_itf)
        end

        private

        def bgs_service
          BGS::Services.new(external_uid: target_veteran.participant_id,
                            external_key: target_veteran.participant_id)
        end
      end
    end
  end
end
