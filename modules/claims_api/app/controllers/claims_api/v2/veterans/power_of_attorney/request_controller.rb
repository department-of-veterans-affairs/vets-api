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

          poa_list_with_dependent_data = add_dependent_data_to_poa_response(poa_list)

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyRequestBlueprint.render(
            poa_list_with_dependent_data, view: :shared_response, root: :data
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
          if poa_request.claimant_icn.present?
            res['claimant_icn'] = poa_request.claimant_icn
            res = add_dependent_data_to_poa_response(res).first
          end

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyRequestBlueprint.render(res, view: :shared_response,
                                                                                              root: :data), status: :ok
        end

        # rubocop:disable Metrics/MethodLength
        def decide
          validate_json_schema('DECIDE')
          lighthouse_id = params[:id]
          decision = normalize(form_attributes['decision'])
          representative_id = form_attributes['representativeId']
          request = find_poa_request!(lighthouse_id)
          proc_id = request.proc_id

          decide_service.validate_decide_representative_params!(request.poa_code, representative_id)

          # There will be a Veteran since we saved the Create request, claimant is optional
          veteran_info, claimant_info = decide_service.build_veteran_and_dependent_data(
            request, method(:build_target_veteran)
          )
          # skip the BGS API calls in lower environments to prevent 3rd parties from creating data in external systems
          unless Flipper.enabled?(:lighthouse_claims_v2_poa_requests_skip_bep)
            # Will either get null when a decision is declined or
            # a poa.id for record saved in our DB when decision is accepted
            decision_response = process_poa_decision(
              decision:, proc_id:, representative_id:, poa_code: request.poa_code, metadata: request.metadata,
              veteran: veteran_info, claimant: claimant_info
            )
            # updates the request with the decision in BGS (BEP)
            manage_representative_update_poa_request(
              proc_id:, secondary_status: decision, declined_reason: form_attributes['declinedReason'],
              service: manage_representative_service
            )
          end

          get_poa_response = decide_service.handle_poa_response(lighthouse_id, veteran_info, claimant_info)
          # Two different responses needed, if declined no location URL is required
          if decision_response.nil?
            render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyRequestBlueprint.render(get_poa_response,
                                                                                           view: :shared_response,
                                                                                           root: :data), status: :ok
          else
            render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyRequestBlueprint.render(
              get_poa_response, view: :shared_response, root: :data
            ), status: :ok, location: url_for(
              controller: 'power_of_attorney/base', action: 'status', id: decision_response.id,
              veteranId: request.veteran_icn
            )
          end
        end
        # rubocop:enable Metrics/MethodLength

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
          unless Flipper.enabled?(:lighthouse_claims_v2_poa_requests_skip_bep)
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
          # The only way to get an ID value returned in Sandbox since we do not save the requests
          if Flipper.enabled?(:lighthouse_claims_v2_poa_requests_skip_bep)
            form_attributes['id'] = 'c5ab49ca-0bd3-4529-8c48-5e277083f9eb'
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

        def add_dependent_data_to_poa_response(poa_list)
          items = Array.wrap(poa_list)

          items.each do |item|
            next unless item['claimant_icn']

            first_name, last_name = get_dependent_name(item['claimant_icn'])
            item['claimantFirstName'] = first_name
            item['claimantLastName'] = last_name
          end

          items
        end

        def get_dependent_name(icn)
          dependent = build_veteran_or_dependent_data(icn)

          [dependent.first_name, dependent.last_name]
        end

        # rubocop:disable Metrics/ParameterLists
        def process_poa_decision(decision:, proc_id:, representative_id:, poa_code:, metadata:, veteran:, claimant:)
          result = ClaimsApi::PowerOfAttorneyRequestService::DecisionHandler.new(
            decision:, proc_id:, registration_number: representative_id, poa_code:, metadata:, veteran:, claimant:
          ).call
          return nil if result.blank?

          @json_body, type = result
          validate_mapped_data!(veteran.participant_id, type, poa_code)
          # build headers
          @claimant_icn = claimant.icn.presence || claimant.mpi.icn if claimant
          build_auth_headers(veteran)
          attrs = decide_request_attributes(poa_code:, decide_form_attributes: form_attributes)
          # save record
          power_of_attorney = ClaimsApi::PowerOfAttorney.create!(attrs)

          claims_v2_logging('process_poa_decision',
                            message: 'Record saved, sending to POA Form Builder Job')
          ClaimsApi::V2::PoaFormBuilderJob.perform_async(power_of_attorney.id, type,
                                                         'post', representative_id)

          power_of_attorney # return to the decide method for the response
        rescue => e
          claims_v2_logging('process_poa_decision',
                            message: "Failed to save power of attorney record. Error: #{e}")
          raise e
        end
        # rubocop:enable Metrics/ParameterLists

        def validate_mapped_data!(veteran_participant_id, type, poa_code)
          claims_v2_logging('process_poa_decision',
                            message: "Data mapped, beginning to validate #{type} and build headers for record save")
          # custom validations, must come first
          @claims_api_forms_validation_errors = validate_form_2122_and_2122a_submission_values(
            user_profile:, veteran_participant_id:, poa_code:,
            base: type
          )
          # JSON validations, all errors, including errors from the custom validations
          # will be raised here if JSON errors exist
          validate_json_schema(type.upcase)
          # otherwise we raise the errors from the custom validations if no JSON
          # errors exist
          log_and_raise_decision_error_message! if @claims_api_forms_validation_errors
        rescue JsonSchema::JsonApiMissingAttribute
          log_and_raise_decision_error_message!
        end

        def log_and_raise_decision_error_message!
          claims_v2_logging('process_poa_decision',
                            message: 'Encountered issues validating the mapped data')

          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: 'An error occurred while processing this decision. Please try again later.'
          )
        end

        def build_auth_headers(veteran)
          params[:veteranId] = veteran.icn.presence || veteran.mpi.icn

          auth_headers
        end

        def decide_request_attributes(poa_code:, decide_form_attributes:)
          {
            status: ClaimsApi::PowerOfAttorney::PENDING,
            auth_headers: set_auth_headers,
            form_data: decide_form_attributes,
            current_poa: poa_code,
            header_hash:
          }
        end

        def build_veteran_or_dependent_data(icn)
          build_target_veteran(veteran_id: icn, loa: { current: 3, highest: 3 })
        end

        def manage_representative_update_poa_request(proc_id:, secondary_status:, declined_reason:, service:)
          response = service.update_poa_request(proc_id:, secondary_status:,
                                                declined_reason:)

          raise Common::Exceptions::Lighthouse::BadGateway if response.blank?
        end

        def decide_service
          ClaimsApi::PowerOfAttorneyRequestService::Decide.new
        end

        def manage_representative_service
          ClaimsApi::ManageRepresentativeService.new(external_uid: Settings.bgs.external_uid,
                                                     external_key: Settings.bgs.external_key)
        end

        def find_poa_request!(lighthouse_id)
          request = ClaimsApi::PowerOfAttorneyRequest.find_by(id: lighthouse_id)

          unless request
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
              detail: "Could not find Power of Attorney request with id: #{lighthouse_id}"
            )
          end

          request
        end

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
