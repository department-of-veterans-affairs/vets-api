# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'
require 'claims_api/v2/params_validation/power_of_attorney'
require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/json_format_validation'
require 'claims_api/v2/power_of_attorney_validation'
require 'claims_api/dependent_claimant_validation'

module ClaimsApi
  module V2
    module Veterans
      class PowerOfAttorney::BaseController < ClaimsApi::V2::Veterans::Base
        include ClaimsApi::V2::PowerOfAttorneyValidation
        include ClaimsApi::PoaVerification
        include ClaimsApi::V2::Error::LighthouseErrorHandler
        include ClaimsApi::V2::JsonFormatValidation
        include ClaimsApi::DependentClaimantValidation
        FORM_NUMBER_INDIVIDUAL = '2122A'
        VA_NOTIFY_KEY = 'va_notify_recipient_identifier'

        ##
        # Retrieves the current Power of Attorney (POA) information for a veteran.
        #
        # Queries BGS to determine if the veteran has an active POA, respecting any expiration dates.
        # If a POA exists, fetches the representative's details (name, phone, type) from the database.
        #
        # @return [JSON] When no POA exists, returns an empty data object: { data: {} }
        # @return [JSON] When POA exists, returns formatted POA details including representative
        #   information and POA code, serialized via PowerOfAttorneyBlueprint
        #
        def show
          poa_code = BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa_code(respect_expiration: true)
          data = poa_code.blank? ? {} : representative(poa_code).merge({ code: poa_code })

          if poa_code.blank?
            render json: { data: }
          else
            render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyBlueprint.render(data, view: :show, root: :data)
          end
        end

        def status
          poa = ClaimsApi::PowerOfAttorney.find_by(id: params[:id])
          unless poa
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
              detail: "Could not find Power of Attorney with id: #{params[:id]}"
            )
          end

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyBlueprint.render(poa, view: :status, root: :data),
                 status: :ok
        end

        private

        def shared_form_validation(form_number)
          # validate target veteran exists
          target_veteran

          base = form_number == '2122' ? 'serviceOrganization' : 'representative'
          poa_code = form_attributes.dig(base, 'poaCode')

          @claims_api_forms_validation_errors = validate_form_2122_and_2122a_submission_values(
            user_profile:, veteran_participant_id: target_veteran.participant_id, poa_code:,
            base:
          )

          validate_json_schema(form_number.upcase)
          @rep_id = validate_registration_number!(base, poa_code)

          add_claimant_data_to_form if user_profile

          if @claims_api_forms_validation_errors
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::JsonFormValidationError,
                  @claims_api_forms_validation_errors
          end
        end

        def validate_registration_number!(base, poa_code)
          rn = form_attributes.dig(base, 'registrationNumber')
          rep = ::Veteran::Service::Representative.where('? = ANY(poa_codes) AND representative_id = ?',
                                                         poa_code,
                                                         rn).order(created_at: :desc).first
          if rep.nil?
            raise ::Common::Exceptions::ResourceNotFound.new(
              detail: "Could not find an Accredited Representative with registration number: #{rn} " \
                      "and poa code: #{poa_code}"
            )
          end
          rep.id
        end

        def attributes(token = nil)
          base = form_attributes.key?('serviceOrganization') ? 'serviceOrganization' : 'representative'
          new_poa_code = form_attributes.dig(base, 'poaCode')

          # Attempt to grab OKTA Client Id if we have a token
          cid = token&.payload&.[]('cid') || nil

          {
            status: ClaimsApi::PowerOfAttorney::PENDING,
            auth_headers: set_auth_headers,
            form_data: form_attributes,
            current_poa: new_poa_code,
            header_hash:,
            cid:
          }
        end

        def submit_power_of_attorney(poa_code, form_number)
          attributes(token).merge!({ source_data: }) unless token.client_credentials_token?

          power_of_attorney = ClaimsApi::PowerOfAttorney.create!(attributes(token))

          unless disable_jobs?
            ClaimsApi::V2::PoaFormBuilderJob.perform_async(power_of_attorney.id, form_number,
                                                           'post', @rep_id)
          end

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyBlueprint.render(
            representative(poa_code).merge({ id: power_of_attorney.id, code: poa_code }),
            view: :show, root: :data
          ), status: :accepted, location: url_for(
            controller: 'power_of_attorney/base', action: 'show', id: power_of_attorney.id
          )
        end

        def set_auth_headers
          headers = auth_headers.merge!({ VA_NOTIFY_KEY => icn_for_vanotify })

          add_dependent_to_auth_headers(headers) if allow_dependent_claimant?
          add_file_number_to_headers(headers)

          headers
        end

        def add_dependent_to_auth_headers(headers)
          claimant = user_profile.profile

          headers.merge!({
                           dependent: {
                             participant_id: claimant.participant_id,
                             ssn: claimant.ssn,
                             first_name: claimant.given_names[0],
                             last_name: claimant.family_name
                           }
                         })
        end

        # This matches the addition in the V1 and used in the dependent assignmment service
        def add_file_number_to_headers(headers)
          file_number = ClaimsApi::VeteranFileNumberLookupService.new(
            target_veteran.ssn, target_veteran.participant_id
          ).check_file_number_exists!
          headers.merge!({ file_number: })
        end

        def validation_success(form_number)
          {
            data: {
              type: "form/#{form_number}/validation",
              attributes: {
                status: 'valid'
              }
            }
          }
        end

        def current_poa_code
          current_poa.try(:code)
        end

        def current_poa
          @current_poa ||= BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa
        end

        def representative(poa_code)
          organization = ::Veteran::Service::Organization.find_by(poa: poa_code)
          return format_organization(organization) if organization.present?

          individuals = ::Veteran::Service::Representative.where('? = ANY(poa_codes)',
                                                                 poa_code).order(created_at: :desc)
          if individuals.blank?
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
              detail: "Could not retrieve Power of Attorney with code: #{poa_code}"
            )
          end

          if individuals.pluck(:representative_id).uniq.count > 1
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(
              detail: "Could not retrieve Power of Attorney due to multiple representatives with code: #{poa_code}"
            )
          end

          format_representative(individuals.first)
        end

        def format_representative(representative)
          {
            name: "#{representative.first_name} #{representative.last_name}",
            phone_number: representative.phone,
            type: 'individual'
          }
        end

        def format_organization(organization)
          {
            name: organization.name,
            phone_number: organization.phone,
            type: 'organization'
          }
        end

        def header_hash
          @header_hash ||= Digest::SHA256.hexdigest(auth_headers.except('va_eauth_authenticationauthority',
                                                                        'va_eauth_service_transaction_id',
                                                                        'va_eauth_issueinstant',
                                                                        'Authorization').to_json)
        end

        def get_poa_code(form_number)
          rep_or_org = form_number.upcase == FORM_NUMBER_INDIVIDUAL ? 'representative' : 'serviceOrganization'
          form_attributes&.dig(rep_or_org, 'poaCode')
        end

        def source_data
          {
            name: source_name,
            icn: nullable_icn,
            email: current_user.email
          }
        end

        def source_name
          return request.headers['X-Consumer-Username'] if token.client_credentials_token?

          "#{current_user.first_name} #{current_user.last_name}"
        end

        def nullable_icn
          current_user.icn
        rescue => e
          ClaimsApi::Logger.log 'POABaseController',
                                level: :warn,
                                detail: 'Failed to retrieve icn for consumer',
                                error_message: e.message
          nil
        end

        def user_profile
          @user_profile ||= fetch_claimant
        end

        def icn_for_vanotify
          dependent_claimant_icn = claimant_icn
          dependent_claimant_icn.presence || params[:veteranId]
        end

        def fetch_claimant
          if claimant_icn.present?
            mpi_profile = mpi_service.find_profile_by_identifier(identifier: claimant_icn,
                                                                 identifier_type: MPI::Constants::ICN)
          end
        rescue ArgumentError
          mpi_profile
        end

        def fetch_ptcpnt_id(vet_icn)
          mpi_profile = mpi_service.find_profile_by_identifier(identifier: vet_icn,
                                                               identifier_type: MPI::Constants::ICN)
          mpi_profile.profile.participant_id
        end

        def claimant_icn
          @claimant_icn ||= form_attributes.dig('claimant', 'claimantId')
        end

        def disable_jobs?
          Settings.claims_api&.poa_v2&.disable_jobs
        end

        def add_claimant_data_to_form
          if user_profile&.status == :ok
            first_name = user_profile.profile.given_names.first
            last_name = user_profile.profile.family_name
            form_attributes['claimant'].merge!(firstName: first_name, lastName: last_name)
          end
        end
      end
    end
  end
end
