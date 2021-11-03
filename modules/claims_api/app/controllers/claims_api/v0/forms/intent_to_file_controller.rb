# frozen_string_literal: true

require 'evss/intent_to_file/service'

module ClaimsApi
  module V0
    module Forms
      class IntentToFileController < ClaimsApi::V0::Forms::Base
        FORM_NUMBER = '0966'
        ITF_TYPES = %w[compensation pension burial].freeze

        # POST to submit intent to file claim.
        #
        # @return [JSON] Response from BGS
        def submit_form_0966
          validate_json_schema

          bgs_response = bgs_service.intent_to_file.insert_intent_to_file(intent_to_file_options)
          render json: bgs_response,
                 serializer: ClaimsApi::IntentToFileSerializer
        rescue Savon::SOAPFault => e
          raise ::Common::Exceptions::UnprocessableEntity.new(detail: e.message&.split('>')&.last)
        end

        # GET current intent to file status based on type.
        #
        # @return [JSON] Response from BGS
        def active
          check_for_type

          bgs_response = bgs_service.intent_to_file.find_intent_to_file_by_ptcpnt_id_itf_type_cd(
            target_veteran.participant_id,
            ClaimsApi::IntentToFile::ITF_TYPES_TO_BGS_TYPES[active_param]
          )
          bgs_active = if bgs_response.is_a?(Array)
                         bgs_response.detect { |itf| active?(itf) }
                       elsif active?(bgs_response)
                         bgs_response
                       end
          message = "No Intent to file is on record for #{target_veteran_name} of type #{active_param}"
          raise ::Common::Exceptions::ResourceNotFound.new(detail: message) if bgs_active.blank?

          render json: bgs_active, serializer: ClaimsApi::IntentToFileSerializer
        end

        # POST to validate 0966 submission payload.
        #
        # @return [JSON] Success if valid, error messages if invalid.
        def validate
          add_deprecation_headers_to_response(response: response, link: ClaimsApi::EndpointDeprecation::V0_DEV_DOCS)
          validate_json_schema
          render json: validation_success
        end

        def schema
          add_deprecation_headers_to_response(response: response, link: ClaimsApi::EndpointDeprecation::V0_DEV_DOCS)
          super
        end

        private

        def participant_claimant_id
          return target_veteran.participant_id unless form_type == 'burial'

          raise ::Common::Exceptions::Forbidden, detail: "Representative cannot file for type 'burial'"
        end

        def intent_to_file_options
          {
            intent_to_file_type_code: ClaimsApi::IntentToFile::ITF_TYPES_TO_BGS_TYPES[form_type],
            participant_claimant_id: form_attributes['participant_claimant_id'] || participant_claimant_id,
            participant_vet_id: form_attributes['participant_vet_id'] || target_veteran.participant_id,
            received_date: received_date || Time.zone.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
            submitter_application_icn_type_code: ClaimsApi::IntentToFile::SUBMITTER_CODE,
            ssn: target_veteran.ssn
          }
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
      end
    end
  end
end
