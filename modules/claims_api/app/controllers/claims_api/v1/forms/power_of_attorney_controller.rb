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

        FORM_NUMBER = '2122'

        # POST to change power of attorney for a Veteran.
        #
        # @return [JSON] Record in pending state
        def submit_form_2122 # rubocop:disable Metrics/MethodLength
          ClaimsApi::Logger.log('poa', detail: '2122 - Request started')
          validate_json_schema

          poa_code = form_attributes.dig('serviceOrganization', 'poaCode')
          validate_poa_code!(poa_code)
          ClaimsApi::Logger.log('poa', poa_id: poa_code, detail: 'POA code validated')
          validate_poa_code_for_current_user!(poa_code) if header_request? && !token.client_credentials_token?
          ClaimsApi::Logger.log('poa', poa_id: poa_code, detail: 'Is valid POA')
          ClaimsApi::Logger.log('poa', poa_id: poa_code, detail: 'Starting file_number check')
          check_file_number_exists!
          ClaimsApi::Logger.log('poa', poa_id: poa_code, detail: 'File number check completed.')

          power_of_attorney = ClaimsApi::PowerOfAttorney.find_using_identifier_and_source(header_md5:,
                                                                                          source_name:)
          ClaimsApi::Logger.log('poa', poa_id: power_of_attorney&.id, detail: 'Located PoA in vets-api')
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
            ClaimsApi::Logger.log('poa', poa_id: power_of_attorney&.id, detail: 'Attributes merged')

            power_of_attorney = ClaimsApi::PowerOfAttorney.create(attributes)
            ClaimsApi::Logger.log('poa', poa_id: power_of_attorney&.id, detail: 'Power of Attorney created')
            unless power_of_attorney.persisted?
              power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(md5: power_of_attorney.md5)
              ClaimsApi::Logger.log('poa', poa_id: power_of_attorney&.id, detail: 'Find_by md5 successful.')
            end

            power_of_attorney.save!
            ClaimsApi::Logger.log('poa', poa_id: power_of_attorney.id, detail: 'Created in Lighthouse')
          end

          data = power_of_attorney.form_data

          if data.dig('signatures', 'veteran').present? && data.dig('signatures', 'representative').present?
            # Autogenerate a 21-22 form from the request body and upload it to VBMS.
            # If upload is successful, then the PoaUpater job is also called to update the code in BGS.
            ClaimsApi::PoaFormBuilderJob.perform_async(power_of_attorney.id)
          end

          ClaimsApi::Logger.log('poa', detail: '2122 - Request Completed')
          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
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

          render json: @power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        # GET the current status of a previous POA change request.
        #
        # @return [JSON] POA record with current status
        def status
          find_poa_by_id
          render json: @power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        # GET current POA for a Veteran.
        #
        # @return [JSON] Last POA change request through Claims API
        def active # rubocop:disable Metrics/MethodLength
          validate_user_is_accredited! if header_request? && !token.client_credentials_token?

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
          ClaimsApi::Logger.log('poa', detail: '2122/validate - Request Started')
          add_deprecation_headers_to_response(response:, link: ClaimsApi::EndpointDeprecation::V1_DEV_DOCS)
          validate_json_schema

          poa_code = form_attributes.dig('serviceOrganization', 'poaCode')
          validate_poa_code!(poa_code)
          validate_poa_code_for_current_user!(poa_code) if header_request? && !token.client_credentials_token?
          ClaimsApi::Logger.log('poa', detail: '2122/validate - Request Completed')

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
          log_message_to_sentry('Failed to retrieve icn for consumer',
                                :warning,
                                body: e.message)

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

        def select_service(ssn)
          # rubocop:disable Rails/DynamicFindBy
          if Flipper.enabled? :bgs_via_faraday_file_number
            ClaimsApi::Logger.log('poa', detail: 'local BGS service used to locate file_number')
            ClaimsApi::LocalBGS.new(
              external_uid: target_veteran.participant_id,
              external_key: target_veteran.participant_id
            ).find_by_ssn(ssn)
          else
            ClaimsApi::Logger.log('poa', detail: 'bgs-ext used to locate file_number')
            bgs_service.people.find_by_ssn(ssn)
          end
          # rubocop:enable Rails/DynamicFindBy
        end

        def check_file_number_exists!
          ssn = target_veteran.ssn

          begin
            response = select_service(ssn)
            ClaimsApi::Logger.log('poa', detail: 'file_number located')
            unless response && response[:file_nbr].present?
              error_message = "Unable to locate Veteran's File Number in Master Person Index (MPI)." \
                              'Please submit an issue at ask.va.gov ' \
                              'or call 1-800-MyVA411 (800-698-2411) for assistance.'
              raise ::Common::Exceptions::UnprocessableEntity.new(detail: error_message)
            end
          rescue BGS::ShareError => e
            error_message = "A BGS failure occurred while trying to retrieve Veteran 'FileNumber'"
            log_exception_to_sentry(e, nil, { message: error_message }, 'warn')
            raise ::Common::Exceptions::FailedDependency
          end
        end
      end
    end
  end
end
