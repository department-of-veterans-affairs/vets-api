# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'
require 'claims_api/dependent_claimant_validation'

module ClaimsApi
  module V1
    module Forms
      class PowerOfAttorneyController < ClaimsApi::V1::Forms::Base
        include ClaimsApi::DocumentValidations
        include ClaimsApi::EndpointDeprecation
        include ClaimsApi::PoaVerification
        include ClaimsApi::DependentClaimantValidation

        before_action except: %i[schema] do
          permit_scopes %w[claim.read] if request.get?
        end
        before_action { permit_scopes %w[claim.write] if request.post? || request.put? }
        before_action except: %i[status active] do
          check_request_ssn_matches_mpi(request&.headers&.to_h) if header_request?
        end
        FORM_NUMBER = '2122'

        # POST to change power of attorney for a Veteran.
        #
        # @return [JSON] Record in pending state
        def submit_form_2122 # rubocop:disable Metrics/MethodLength
          validate_json_schema

          poa_code = form_attributes.dig('serviceOrganization', 'poaCode')
          validate_poa_code!(poa_code)
          validate_poa_code_for_current_user!(poa_code) if header_request? && !token.client_credentials_token?
          file_number = ClaimsApi::VeteranFileNumberLookupService.new(
            target_veteran.ssn, veteran_participant_id
          ).check_file_number_exists!
          claimant_information = validate_dependent_claimant!(poa_code:)

          primary_identifier = {}
          primary_identifier[:header_hash] = header_hash || primary_identifier[:header_md5] = header_md5

          power_of_attorney = ClaimsApi::PowerOfAttorney.find_using_identifier_and_source(primary_identifier,
                                                                                          source_name)

          unless power_of_attorney&.status&.in?(%w[submitted pending])
            attributes = {
              status: ClaimsApi::PowerOfAttorney::PENDING,
              auth_headers:,
              form_data: form_attributes,
              current_poa: power_of_attorney_verifier.current_poa_code,
              header_hash:,
              cid: token.payload['cid']
            }
            attributes.merge!({ source_data: }) unless token.client_credentials_token?
            power_of_attorney = ClaimsApi::PowerOfAttorney.create(attributes)
            unless power_of_attorney.persisted?
              power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(header_hash: power_of_attorney.header_hash)
            end

            if allow_dependent_claimant?
              update_auth_headers_for_dependent(
                power_of_attorney,
                claimant_information
              )
            end

            power_of_attorney.auth_headers['participant_id'] = veteran_participant_id
            power_of_attorney.auth_headers['file_number'] = file_number
            power_of_attorney.save!
          end

          data = power_of_attorney.form_data

          if data.dig('signatures', 'veteran').present? && data.dig('signatures', 'representative').present?
            # Autogenerate a 21-22 form from the request body and upload it to VBMS.
            # If upload is successful, then the PoaUpater job is also called to update the code in BGS.
            ClaimsApi::V1::PoaFormBuilderJob.perform_async(power_of_attorney.id, 'post')
          end

          claims_v1_logging('poa_submit', message: "poa_submit complete, poa: #{power_of_attorney&.id}")
          render json: ClaimsApi::PowerOfAttorneySerializer.new(power_of_attorney)
        end

        # PUT to upload a wet-signed 2122 form.
        # Required if "signatures" not supplied in above POST.
        #
        # @return [JSON] Claim record
        def upload
          validate_document_provided
          validate_documents_content_type
          validate_documents_page_size
          find_poa_by_id
          ClaimsApi::VeteranFileNumberLookupService.new(target_veteran.ssn,
                                                        veteran_participant_id).check_file_number_exists!

          @power_of_attorney.set_file_data!(documents.first, params[:doc_type])
          @power_of_attorney.status = ClaimsApi::PowerOfAttorney::SUBMITTED
          @power_of_attorney.auth_headers['participant_id'] = veteran_participant_id
          @power_of_attorney.save!
          @power_of_attorney.reload

          # If upload is successful, then the PoaUpater job is also called to update the code in BGS.
          ClaimsApi::PoaVBMSUploadJob.perform_async(@power_of_attorney.id, 'put')

          render json: ClaimsApi::PowerOfAttorneySerializer.new(@power_of_attorney)
        end

        # GET the current status of a previous POA change request.
        #
        # @return [JSON] POA record with current status
        def status
          find_poa_by_id

          render json: ClaimsApi::PowerOfAttorneySerializer.new(@power_of_attorney)
        end

        # GET current POA for a Veteran.
        #
        # @return [JSON] Last POA change request through Claims API
        def active # rubocop:disable Metrics/MethodLength
          if header_request? && !token.client_credentials_token? && !verify_power_of_attorney!
            claims_v1_logging 'poa_v1_active',
                              level: :warn,
                              message: "POA not found, poa: #{@power_of_attorney&.id}"
          end

          unless power_of_attorney_verifier.current_poa_code
            claims_v1_logging('poa_v1_active', message: "POA not found, poa: #{@power_of_attorney&.id}")
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'POA not found')
          end

          representative_info = build_representative_info(power_of_attorney_verifier.current_poa_code)

          render json: {
            data: {
              id: nil,
              type: 'claims_api_power_of_attorneys',
              attributes: {
                status: ClaimsApi::PowerOfAttorney::UPDATED,
                date_request_accepted: current_poa_begin_date,
                representative: {
                  service_organization: {
                    first_name: representative_info[:first_name],
                    last_name: representative_info[:last_name],
                    organization_name: representative_info[:organization_name],
                    phone_number: representative_info[:phone_number],
                    poa_code: power_of_attorney_verifier.current_poa_code
                  }
                },
                previous_poa: power_of_attorney_verifier.previous_poa_code
              }
            }
          }
        end

        # POST to validate 2122 submission payload.
        #
        # @return [JSON] Success if valid, error messages if invalid.
        def validate
          add_deprecation_headers_to_response(response:, link: ClaimsApi::EndpointDeprecation::V1_DEV_DOCS)
          validate_json_schema

          poa_code = form_attributes.dig('serviceOrganization', 'poaCode')
          validate_poa_code!(poa_code)
          validate_poa_code_for_current_user!(poa_code) if header_request? && !token.client_credentials_token?
          validate_dependent_claimant!(poa_code:)

          render json: validation_success
        end

        private

        def update_auth_headers_for_dependent(poa, claimant_information)
          auth_headers = poa.auth_headers

          auth_headers.merge!({
                                dependent: {
                                  first_name: claimant_information['claimant_first_name'],
                                  last_name: claimant_information['claimant_last_name'],
                                  participant_id: claimant_information['claimant_participant_id'],
                                  ssn: claimant_information['claimant_ssn']
                                }
                              })
        end

        def validate_dependent_claimant!(poa_code:)
          return nil unless allow_dependent_claimant?

          veteran_participant_id = target_veteran.participant_id
          claimant_first_name = form_attributes.dig('claimant', 'firstName')
          claimant_last_name = form_attributes.dig('claimant', 'lastName')
          service = ClaimsApi::DependentClaimantVerificationService.new(veteran_participant_id:,
                                                                        claimant_first_name:,
                                                                        claimant_last_name:,
                                                                        poa_code:)

          service.validate_poa_code_exists!
          service.validate_dependent_by_participant_id!

          {
            'claimant_participant_id' => service.claimant_participant_id,
            'claimant_first_name' => claimant_first_name,
            'claimant_last_name' => claimant_last_name,
            'claimant_ssn' => service.claimant_ssn
          }
        end

        def current_poa_begin_date
          return nil if power_of_attorney_verifier.current_poa.try(:begin_date).blank?

          Date.strptime(power_of_attorney_verifier.current_poa.begin_date, '%m/%d/%Y')
        end

        def power_of_attorney_verifier
          @verifier ||= BGS::PowerOfAttorneyVerifier.new(target_veteran)
        end

        def header_md5
          @header_md5 ||= Digest::MD5.hexdigest(auth_headers.except('va_eauth_authenticationauthority',
                                                                    'va_eauth_service_transaction_id',
                                                                    'va_eauth_issueinstant',
                                                                    'Authorization').to_json)
        end

        def header_hash
          @header_hash ||= Digest::SHA256.hexdigest(auth_headers.except('va_eauth_authenticationauthority',
                                                                        'va_eauth_service_transaction_id',
                                                                        'va_eauth_issueinstant',
                                                                        'Authorization').to_json)
        end

        def source_data
          {
            name: source_name,
            icn: nullable_icn,
            email: current_user.email
          }
        end

        def nullable_icn
          current_user.icn
        rescue => e
          claims_v1_logging('poa_nullable_icn', message: "#{e.message}, poa: #{@power_of_attorney.id}")
          nil
        end

        def find_poa_by_id
          @power_of_attorney = ClaimsApi::PowerOfAttorney.find_by id: params[:id]
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found') unless @power_of_attorney
        end

        def validation_success
          {
            data: {
              type: 'powerOfAttorneyValidation',
              attributes: {
                status: 'valid'
              }
            }
          }
        end

        def build_representative_info(poa_code)
          if poa_code_in_organization?(poa_code)
            veteran_service_organization = ::Veteran::Service::Organization.find_by(poa: poa_code)
            {
              first_name: nil,
              last_name: nil,
              organization_name: veteran_service_organization.name,
              phone_number: veteran_service_organization.phone
            }
          else
            representative = ::Veteran::Service::Representative.where('? = ANY(poa_codes)', poa_code).first
            if representative.blank?
              raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Power of Attorney not found')
            end

            {
              first_name: representative.first_name,
              last_name: representative.last_name,
              organization_name: nil,
              phone_number: representative.phone
            }
          end
        end

        def veteran_participant_id
          target_veteran.participant_id
        end

        def check_request_ssn_matches_mpi(req_headers)
          req_ssn = req_headers['HTTP_X_VA_SSN']
          ssn = target_veteran.mpi.profile.ssn
          unless ssn == req_ssn && ssn.present?
            error_message = 'The SSN provided does not match Master Person Index (MPI). ' \
                            'Please correct the SSN or submit an issue at ask.va.gov ' \
                            'or call 1-800-MyVA411 (800-698-2411) for assistance.'
            claims_v1_logging('poa_check_request_ssn_matches_mpi',
                              message: 'Request SSN did not match the one found in MPI.')
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: error_message)
          end
        end
      end
    end
  end
end
