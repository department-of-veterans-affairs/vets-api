# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'
require 'bgs_service/local_bgs'

module ClaimsApi
  module V1
    module Forms
      class PowerOfAttorneyController < ClaimsApi::V1::Forms::Base
        include ClaimsApi::DocumentValidations
        include ClaimsApi::EndpointDeprecation
        include ClaimsApi::PoaVerification

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
          check_file_number_exists!

          power_of_attorney = ClaimsApi::PowerOfAttorney.find_using_identifier_and_source(header_md5:,
                                                                                          source_name:)
          unless power_of_attorney&.status&.in?(%w[submitted pending])
            attributes = {
              status: ClaimsApi::PowerOfAttorney::PENDING,
              auth_headers:,
              form_data: form_attributes,
              current_poa: current_poa_code,
              header_md5:,
              cid: token.payload['cid']
            }
            attributes.merge!({ source_data: }) unless token.client_credentials_token?
            power_of_attorney = ClaimsApi::PowerOfAttorney.create(attributes)
            unless power_of_attorney.persisted?
              power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(md5: power_of_attorney.md5)
            end

            power_of_attorney.save!
          end

          data = power_of_attorney.form_data

          if data.dig('signatures', 'veteran').present? && data.dig('signatures', 'representative').present?
            # Autogenerate a 21-22 form from the request body and upload it to VBMS.
            # If upload is successful, then the PoaUpater job is also called to update the code in BGS.
            ClaimsApi::V1::PoaFormBuilderJob.perform_async(power_of_attorney.id)
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
          check_file_number_exists!

          @power_of_attorney.set_file_data!(documents.first, params[:doc_type])
          @power_of_attorney.status = ClaimsApi::PowerOfAttorney::SUBMITTED
          @power_of_attorney.save!
          @power_of_attorney.reload

          # If upload is successful, then the PoaUpater job is also called to update the code in BGS.
          ClaimsApi::PoaVBMSUploadJob.perform_async(@power_of_attorney.id)

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
          validate_user_is_accredited! if header_request? && !token.client_credentials_token?

          unless current_poa_code
            claims_v1_logging('poa_active', message: "POA not found, poa: #{@power_of_attorney&.id}")
          end
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'POA not found') unless current_poa_code

          representative_info = build_representative_info(current_poa_code)

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
                    poa_code: current_poa_code
                  }
                },
                previous_poa: previous_poa_code
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

          render json: validation_success
        end

        private

        def current_poa_begin_date
          return nil if current_poa.try(:begin_date).blank?

          Date.strptime(current_poa.begin_date, '%m/%d/%Y')
        end

        def current_poa_code
          current_poa.try(:code)
        end

        def current_poa
          @current_poa ||= BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa
        end

        def previous_poa_code
          @previous_poa_code ||= BGS::PowerOfAttorneyVerifier.new(target_veteran).previous_poa_code
        end

        def header_md5
          @header_md5 ||= Digest::MD5.hexdigest(auth_headers.except('va_eauth_authenticationauthority',
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

        def find_by_ssn(ssn)
          # rubocop:disable Rails/DynamicFindBy
          ClaimsApi::LocalBGS.new(
            external_uid: target_veteran.participant_id,
            external_key: target_veteran.participant_id
          ).find_by_ssn(ssn)
          # rubocop:enable Rails/DynamicFindBy
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

        def check_file_number_exists!
          ssn = target_veteran&.ssn

          begin
            response = find_by_ssn(ssn)
            unless response && response[:file_nbr].present?
              error_message = "Unable to locate Veteran's File Number in Master Person Index (MPI). " \
                              'Please submit an issue at ask.va.gov ' \
                              'or call 1-800-MyVA411 (800-698-2411) for assistance.'
              raise ::Common::Exceptions::UnprocessableEntity.new(detail: error_message)
            end
          rescue BGS::ShareError
            error_message = "A BGS failure occurred while trying to retrieve Veteran 'FileNumber'"
            claims_v1_logging('poa_find_by_ssn', message: error_message)
            raise ::Common::Exceptions::FailedDependency
          end
        end
      end
    end
  end
end
