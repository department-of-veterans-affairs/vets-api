# frozen_string_literal: true

require 'bgs_service/manage_representative_service'
require 'claims_api/common/exceptions/lighthouse/bad_gateway'
require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/json_format_validation'
require 'brd/brd'

module ClaimsApi
  module V2
    module Veterans
      class PowerOfAttorney::RequestController < ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController
        FORM_NUMBER = 'POA_REQUEST'
        MAX_PAGE_SIZE = 100
        MAX_PAGE_NUMBER = 100
        DEFAULT_PAGE_SIZE = 10
        DEFAULT_PAGE_NUMBER = 1

        # POST /power-of-attorney-requests
        def index
          poa_codes = form_attributes['poaCodes']
          validate_page_size_and_number_params

          filter = form_attributes['filter'] || {}

          verify_poa_codes_data(poa_codes)
          validate_filter!(filter)

          service = ClaimsApi::PowerOfAttorneyRequestService::Index.new(
            poa_codes:,
            page_size: @page_size_param,
            page_index: page_number_to_index(@page_number_param),
            filter:
          )

          poa_list = service.get_poa_list

          raise Common::Exceptions::Lighthouse::BadGateway unless poa_list

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyRequestBlueprint.render(
            poa_list, view: :index_or_show, root: :data
          ), status: :ok
        end

        def show
          poa_request = ClaimsApi::PowerOfAttorneyRequest.find_by(id: params[:id])

          unless poa_request
            raise Common::Exceptions::Lighthouse::ResourceNotFound.new(
              detail: "Could not find Power of Attorney Request with id: #{params[:id]}"
            )
          end

          params[:veteranId] = poa_request.veteran_icn # needed for target_veteran
          participant_id = target_veteran.participant_id

          service = ClaimsApi::PowerOfAttorneyRequestService::Show.new(participant_id)

          res = service.get_poa_request
          res['id'] = poa_request.id

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyRequestBlueprint.render(res, view: :index_or_show,
                                                                                              root: :data),
                 status: :ok
        end

        def decide # rubocop:disable Metrics/MethodLength
          lighthouse_id = params[:id]
          decision = normalize(form_attributes['decision'])
          representative_id = form_attributes['representativeId']

          request = ClaimsApi::PowerOfAttorneyRequest.find_by(id: lighthouse_id)
          unless request
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
              detail: "Could not find Power of Attorney request with id: #{lighthouse_id}"
            )
          end
          proc_id = request.proc_id
          vet_icn = request.veteran_icn

          validate_decide_params!(proc_id:, decision:)

          service = ClaimsApi::ManageRepresentativeService.new(external_uid: Settings.bgs.external_uid,
                                                               external_key: Settings.bgs.external_key)

          ptcpnt_id = fetch_ptcpnt_id(vet_icn)
          if decision == 'declined'
            poa_request = validate_ptcpnt_id!(ptcpnt_id:, proc_id:, representative_id:, service:)
          end

          first_name = poa_request['claimantFirstName'].presence || poa_request['vetFirstName'] if poa_request

          res = service.update_poa_request(proc_id:, secondary_status: decision,
                                           declined_reason: form_attributes['declinedReason'])

          raise Common::Exceptions::Lighthouse::BadGateway if res.blank?

          send_declined_notification(ptcpnt_id:, first_name:, representative_id:) if decision == 'declined'

          service = ClaimsApi::PowerOfAttorneyRequestService::Show.new(ptcpnt_id)
          res = service.get_poa_request
          res['id'] = lighthouse_id

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyRequestBlueprint.render(res, view: :index_or_show,
                                                                                              root: :data),
                 status: :ok
        end

        def create # rubocop:disable Metrics/MethodLength
          validate_country_code
          # validate target veteran exists
          target_veteran

          poa_code = form_attributes.dig('representative', 'poaCode')
          @claims_api_forms_validation_errors = validate_form_2122_and_2122a_submission_values(user_profile:)

          validate_json_schema(FORM_NUMBER)
          validate_accredited_representative(poa_code)
          validate_accredited_organization(poa_code)

          # if we get here, the only errors not raised are form value validation errors
          if @claims_api_forms_validation_errors
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::JsonFormValidationError,
                  @claims_api_forms_validation_errors
          end

          bgs_form_attributes = build_bgs_attributes(form_attributes)

          # skip the BGS API calls in lower environments to prevent 3rd parties from creating data in external systems
          unless Flipper.enabled?(:lighthouse_claims_v2_poa_requests_skip_bgs)
            res = ClaimsApi::PowerOfAttorneyRequestService::Orchestrator
                  .new(target_veteran.participant_id,
                       bgs_form_attributes.deep_symbolize_keys,
                       user_profile&.profile&.participant_id).submit_request

            claimant_icn = form_attributes.dig('claimant', 'claimantId')
            poa_request = ClaimsApi::PowerOfAttorneyRequest.create!(proc_id: res['procId'],
                                                                    veteran_icn: params[:veteranId],
                                                                    claimant_icn:, poa_code:,
                                                                    metadata: res['meta'])
            form_attributes['id'] = poa_request.id
          end

          response_data = ClaimsApi::V2::Blueprints::PowerOfAttorneyRequestBlueprint.render(form_attributes,
                                                                                            view: :create,
                                                                                            root: :data)

          options = { status: :created }
          if form_attributes['id'].present?
            options[:location] =
              url_for(controller: 'base', action: 'status', id: form_attributes['id'])
          end

          render json: response_data, **options
        end

        private

        def validate_country_code
          vet_cc = form_attributes.dig('veteran', 'address', 'countryCode')
          claimant_cc = form_attributes.dig('claimant', 'address', 'countryCode')

          if ClaimsApi::BRD::COUNTRY_CODES[vet_cc.to_s.upcase].blank?
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: 'The country provided is not valid.'
            )
          end

          if claimant_cc.present? && ClaimsApi::BRD::COUNTRY_CODES[claimant_cc.to_s.upcase].blank?
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: 'The country provided is not valid.'
            )
          end
        end

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

        def validate_accredited_representative(poa_code)
          @representative = ::Veteran::Service::Representative.where('? = ANY(poa_codes)',
                                                                     poa_code).order(created_at: :desc).first
          # there must be a representative to appoint. This representative can be an accredited attorney, claims agent,
          #   or representative.
          if @representative.nil?
            raise ::Common::Exceptions::ResourceNotFound.new(
              detail: "Could not find an Accredited Representative with poa code: #{poa_code}"
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

        def validate_filter!(filter)
          return nil if filter.blank?

          valid_filters = %w[status state city country]

          invalid_filters = filter.keys - valid_filters

          if invalid_filters.any?
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: "Invalid filter(s): #{invalid_filters.join(', ')}"
            )
          end

          validate_statuses!(filter['status'])
        end

        def validate_statuses!(statuses)
          return nil if statuses.blank?

          unless statuses.is_a?(Array)
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: 'filter status must be an array'
            )
          end

          valid_statuses = ManageRepresentativeService::ALL_STATUSES

          if statuses.any? { |status| valid_statuses.exclude?(status.upcase) }
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: "Status(es) must be one of: #{valid_statuses.join(', ')}"
            )
          end
        end

        def validate_page_size_and_number_params
          return if use_defaults?

          valid_page_param?('size') if params[:page][:size]
          valid_page_param?('number') if params[:page][:number]

          @page_size_param = params[:page][:size] ? params[:page][:size].to_i : DEFAULT_PAGE_SIZE
          @page_number_param = params[:page][:number] ? params[:page][:number].to_i : DEFAULT_PAGE_NUMBER

          verify_under_max_values!
        end

        def use_defaults?
          if params[:page].blank?
            @page_size_param = DEFAULT_PAGE_SIZE
            @page_number_param = DEFAULT_PAGE_NUMBER

            true
          end
        end

        def verify_under_max_values!
          if @page_size_param && @page_size_param > MAX_PAGE_SIZE
            raise_param_exceeded_warning = true
            include_page_size_msg = true
          end
          if @page_number_param && @page_number_param > MAX_PAGE_NUMBER
            raise_param_exceeded_warning = true
            include_page_number_msg = true
          end
          if raise_param_exceeded_warning.present?
            build_params_error_msg(include_page_size_msg,
                                   include_page_number_msg)
          end
        end

        def valid_page_param?(key)
          param_val = params[:page][:"#{key}"]
          return true if param_val.is_a?(String) && param_val.match?(/^\d+?$/) && param_val

          raise ::Common::Exceptions::BadRequest.new(
            detail: "The page[#{key}] param value #{params[:page][:"#{key}"]} is invalid"
          )
        end

        def build_params_error_msg(include_page_size_msg, include_page_number_msg)
          if include_page_size_msg.present? && include_page_number_msg.present?
            msg = "Both the maximum page size param value of #{MAX_PAGE_SIZE} has been exceeded and " \
                  "the maximum page number param value of #{MAX_PAGE_NUMBER} has been exceeded."
          elsif include_page_size_msg.present?
            msg = "The maximum page size param value of #{MAX_PAGE_SIZE} has been exceeded."
          elsif include_page_number_msg.present?
            msg = "The maximum page number param value of #{MAX_PAGE_NUMBER} has been exceeded."
          end

          raise ::Common::Exceptions::BadRequest.new(
            detail: msg
          )
        end

        def verify_poa_codes_data(poa_codes)
          unless poa_codes.is_a?(Array) && poa_codes.size.positive?
            raise ::Common::Exceptions::ParameterMissing.new('poaCodes',
                                                             detail: 'poaCodes is required and cannot be empty')
          end
        end

        def page_number_to_index(number)
          return 0 if number <= 0

          number - 1
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
