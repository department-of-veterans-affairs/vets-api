# frozen_string_literal: true

require 'claims_api/v2/params_validation/intent_to_file'
require 'bgs_service/local_bgs'

module ClaimsApi
  module V2
    module Veterans
      class IntentToFileController < ClaimsApi::V2::ApplicationController
        before_action :validate_request_format, only: %i[submit validate]

        # GET to fetch active intent to file by type
        #
        # @return [JSON] ITF record
        def type # rubocop:disable Metrics/MethodLength
          claims_v2_logging('itf_type', message: "type: #{get_bgs_type(params)}, starting itf type")

          validate_request!(ClaimsApi::V2::ParamsValidation::IntentToFile)

          type = get_bgs_type(params)
          response = local_bgs_service.find_intent_to_file_by_ptcpnt_id_itf_type_cd(
            target_veteran.participant_id,
            type
          )
          message = "No active '#{get_bgs_type(params)}' intent to file found."
          claims_v2_logging('itf_type', message: "#{message}, type: #{get_bgs_type(params)}") if response.blank?
          raise ::Common::Exceptions::ResourceNotFound.new(detail: message) if response.blank?

          response = [response] unless response.is_a?(Array)
          intent_to_files = response.compact.collect do |element|
            bgs_itf_to_lighthouse_itf(bgs_itf: element)
          end

          active_itf = intent_to_files.detect do |itf|
            itf[:status].casecmp?('active') && itf[:expiration_date].to_datetime > Time.zone.now
          end

          if response.blank?
            claims_v2_logging('itf_type',
                              message: "itf resource not found, type: #{get_bgs_type(params)}")
          end
          raise ::Common::Exceptions::ResourceNotFound.new(detail: message) if active_itf.blank?

          itf_id = response.is_a?(Array) ? response[0][:intent_to_file_id] : response[:intent_to_file_id]
          claims_v2_logging('itf_type',
                            message: "ending itf type, itf_id: #{itf_id}, type: #{get_bgs_type(params)}")
          render json: ClaimsApi::V2::Blueprints::IntentToFileBlueprint.render(active_itf, root: :data)
        end

        def submit
          claims_v2_logging('itf_submit', message: 'starting itf submit')
          validate_request!(ClaimsApi::V2::ParamsValidation::IntentToFile)
          type = get_bgs_type(params)

          options = build_options_and_validate(type)

          bgs_response = local_bgs_service.insert_intent_to_file(options)
          if bgs_response.empty?
            ClaimsApi::IntentToFile.create!(status: ClaimsApi::IntentToFile::ERRORED, cid: token.payload['cid'])
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Veteran ID not found')
          else
            ClaimsApi::IntentToFile.create!(status: ClaimsApi::IntentToFile::SUBMITTED, cid: token.payload['cid'])
            claims_v2_logging('itf_submit', message: 'Submitted to BGS')
            lighthouse_itf = bgs_itf_to_lighthouse_itf(bgs_itf: bgs_response)

            itf_id = bgs_response.is_a?(Array) ? bgs_response[0][:intent_to_file_id] : bgs_response[:intent_to_file_id]
            claims_v2_logging('itf_submit', message: "ending itf submit, ift_id: #{itf_id}, type: #{type}")
            render json: ClaimsApi::V2::Blueprints::IntentToFileBlueprint.render(lighthouse_itf, root: :data)
          end
        end

        def validate
          claims_v2_logging('itf_validate', message: 'starting itf validate')
          validate_request!(ClaimsApi::V2::ParamsValidation::IntentToFile)
          type = get_bgs_type(params)
          build_options_and_validate(type)
          claims_v2_logging('itf_validate', message: "ending itf validate, type: #{type}")
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

        def validate_request_format
          if params[:data].nil? || params[:data][:attributes].nil?
            message = 'Request body is not in the correct format.'
            raise ::Common::Exceptions::BadRequest.new(detail: message)
          end
        end

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
          handle_claimant_fields(options:, params:, target_veteran:)
        end

        # BGS requires at least 1 of 'participant_claimant_id' or 'claimant_ssn'
        def handle_claimant_fields(options:, params:, target_veteran:)
          claimant_ssn = params[:data][:attributes][:claimantSsn]
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
          params[:data] ? itf_types[params[:data][:attributes][:type].downcase] : itf_types[params[:type].downcase]
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
