# frozen_string_literal: true

require 'bgs_service/manage_representative_service'
require 'claims_api/common/exceptions/lighthouse/bad_gateway'
require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/json_format_validation'

module ClaimsApi
  module V2
    module Veterans
      class PowerOfAttorney::RequestController < ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController
        FORM_NUMBER = 'POA_REQUEST'

        def index
          poa_codes = form_attributes['poaCodes']

          unless poa_codes.is_a?(Array) && poa_codes.size.positive?
            raise ::Common::Exceptions::ParameterMissing.new('poaCodes',
                                                             detail: 'poaCodes is required and cannot be empty')
          end

          service = ManageRepresentativeService.new(external_uid: 'power_of_attorney_request_uid',
                                                    external_key: 'power_of_attorney_request_key')

          res = service.read_poa_request(poa_codes:)

          poa_list = res['poaRequestRespondReturnVOList']

          raise Common::Exceptions::Lighthouse::BadGateway unless poa_list

          render json: poa_list, status: :ok
        end

        def decide
          proc_id = form_attributes['procId']
          ptcpnt_id = form_attributes['participantId']
          decision = normalize(form_attributes['decision'])
          representative_id = form_attributes['representativeId']

          validate_decide_params!(proc_id:, decision:)

          service = ManageRepresentativeService.new(external_uid: 'power_of_attorney_request_uid',
                                                    external_key: 'power_of_attorney_request_key')

          if decision == 'declined'
            poa_request = validate_ptcpnt_id!(ptcpnt_id:, proc_id:, representative_id:, service:)
          end

          first_name = poa_request['claimantFirstName'] || poa_request['vetFirstName'].presence if poa_request

          res = service.update_poa_request(proc_id:, secondary_status: decision,
                                           declined_reason: form_attributes['declinedReason'])

          raise Common::Exceptions::Lighthouse::BadGateway if res.blank?

          send_declined_notification(ptcpnt_id:, first_name:, representative_id:) if decision == 'declined'

          render json: res, status: :ok
        end

        def create
          # validate target veteran exists
          target_veteran

          poa_code = form_attributes.dig('poa', 'poaCode')
          @claims_api_forms_validation_errors = validate_form_2122_and_2122a_submission_values(user_profile:)

          validate_json_schema(FORM_NUMBER)
          validate_accredited_representative(form_attributes.dig('poa', 'registrationNumber'),
                                             poa_code)
          validate_accredited_organization(poa_code)

          # if we get here, the only errors not raised are form value validation errors
          if @claims_api_forms_validation_errors
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::JsonFormValidationError,
                  @claims_api_forms_validation_errors
          end

          bgs_form_attributes = build_bgs_attributes(form_attributes)

          # skip the BGS API calls in lower environments to prevent 3rd parties from creating data in external systems
          unless Flipper.enabled?(:lighthouse_claims_v2_poa_requests_skip_bgs)
            res = ClaimsApi::PowerOfAttorneyRequestService::Orchestrator.new(target_veteran.participant_id,
                                                                             bgs_form_attributes.deep_symbolize_keys,
                                                                             user_profile&.profile&.participant_id,
                                                                             :poa).submit_request
            form_attributes['procId'] = res['procId']
          end

          # return only the form information consumers provided
          render json: { data: { attributes: form_attributes } }, status: :created
        end

        private

        def validate_decide_params!(proc_id:, decision:)
          if proc_id.blank?
            raise ::Common::Exceptions::ParameterMissing.new('procId',
                                                             detail: 'procId is required')
          end

          unless decision.present? && %w[accepted declined].include?(decision)
            raise ::Common::Exceptions::ParameterMissing.new(
              'decision',
              detail: 'decision is required and must be either "ACCEPTED" or "DECLINED"'
            )
          end
        end

        def send_declined_notification(ptcpnt_id:, first_name:, representative_id:)
          lockbox = Lockbox.new(key: Settings.lockbox.master_key)
          encrypted_ptcpnt_id = Base64.strict_encode64(lockbox.encrypt(ptcpnt_id))
          encrypted_first_name = Base64.strict_encode64(lockbox.encrypt(first_name))

          ClaimsApi::VANotifyDeclinedJob.perform_async(encrypted_ptcpnt_id, encrypted_first_name, representative_id)
        end

        def validate_ptcpnt_id!(ptcpnt_id:, proc_id:, representative_id:, service:)
          if ptcpnt_id.blank?
            raise ::Common::Exceptions::ParameterMissing.new('ptcpntId',
                                                             detail: 'ptcpntId is required if decision is declined')
          end

          if representative_id.blank?
            raise ::Common::Exceptions::ParameterMissing
              .new('representativeId', detail: 'representativeId is required if decision is declined')
          end

          res = service.read_poa_request_by_ptcpnt_id(ptcpnt_id:)

          raise ::Common::Exceptions::Lighthouse::BadGateway if res.blank?

          poa_requests = Array.wrap(res['poaRequestRespondReturnVOList'])

          matching_request = poa_requests.find { |poa_request| poa_request['procID'] == proc_id }

          detail = 'Participant ID/Process ID combination not found'
          raise ::Common::Exceptions::ResourceNotFound.new(detail:) if matching_request.nil?

          matching_request
        end

        def validate_accredited_representative(registration_number, poa_code)
          @representative = ::Veteran::Service::Representative.where('? = ANY(poa_codes) AND representative_id = ?',
                                                                     poa_code,
                                                                     registration_number).order(created_at: :desc).first
          # there must be a representative to appoint. This representative can be an accredited attorney, claims agent,
          #   or representative.
          if @representative.nil?
            raise ::Common::Exceptions::ResourceNotFound.new(
              detail: "Could not find an Accredited Representative with registration number: #{registration_number} " \
                      "and poa code: #{poa_code}"
            )
          end
        end

        def validate_accredited_organization(poa_code)
          # organization is not required. An attorney or claims agent appointment request would not have an accredited
          #   organization to associate with.
          @organization = ::Veteran::Service::Organization.find_by(poa: poa_code)
        end

        def build_bgs_attributes(form_attributes)
          bgs_form_attributes = form_attributes.deep_merge(veteran_data)
          bgs_form_attributes.deep_merge!(claimant_data) if user_profile&.status == :ok
          bgs_form_attributes.deep_merge!(representative_data)
          bgs_form_attributes.deep_merge!(organization_data) if @organization

          bgs_form_attributes
        end

        def normalize(item)
          item.to_s.strip.downcase
        end

        def veteran_data
          {
            'veteran' => {
              'firstName' => target_veteran.first_name,
              'lastName' => target_veteran.last_name,
              'ssn' => target_veteran.ssn,
              'birthdate' => target_veteran.birth_date.to_time.iso8601,
              'va_file_number' => target_veteran.birls_id
            }
          }
        end

        def claimant_data
          {
            'claimant' => {
              'firstName' => user_profile.profile.given_names.first,
              'lastName' => user_profile.profile.family_name,
              'ssn' => user_profile.profile.ssn,
              'birthdate' => user_profile.profile.birth_date.to_time.iso8601,
              'va_file_number' => user_profile.profile.birls_id
            }
          }
        end

        def representative_data
          {
            'poa' => {
              'firstName' => @representative.first_name,
              'lastName' => @representative.last_name
            }
          }
        end

        def organization_data
          {
            'poa' => {
              'organizationName' => @organization.name
            }
          }
        end
      end
    end
  end
end
