# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'

module ClaimsApi
  module V1
    module Forms
      class PowerOfAttorneyController < ClaimsApi::V1::Forms::Base
        include ClaimsApi::DocumentValidations
        include ClaimsApi::EndpointDeprecation

        before_action except: %i[schema] do
          permit_scopes %w[claim.write]
        end

        FORM_NUMBER = '2122'

        # POST to change power of attorney for a Veteran.
        #
        # @return [JSON] Record in pending state
        def submit_form_2122 # rubocop:disable Metrics/MethodLength
          validate_json_schema

          power_of_attorney = ClaimsApi::PowerOfAttorney.find_using_identifier_and_source(header_md5: header_md5,
                                                                                          source_name: source_name)
          unless power_of_attorney&.status&.in?(%w[submitted pending])
            power_of_attorney = ClaimsApi::PowerOfAttorney.create(
              status: ClaimsApi::PowerOfAttorney::PENDING,
              auth_headers: auth_headers,
              form_data: form_attributes,
              source_data: source_data,
              current_poa: current_poa,
              header_md5: header_md5
            )

            unless power_of_attorney.persisted?
              power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(md5: power_of_attorney.md5)
            end

            power_of_attorney.save!
          end

          # This job only occurs when a Veteran submits a PoA request, they are not required to submit a document.
          ClaimsApi::PoaUpdater.perform_async(power_of_attorney.id) unless header_request?
          data = power_of_attorney.form_data
          ClaimsApi::PoaFormBuilderJob.perform_async(power_of_attorney.id) if data['signatures'].present?

          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        # PUT to upload a wet-signed 2122 form.
        # Required if "signatures" not supplied in above POST.
        #
        # @return [JSON] Claim record
        def upload
          validate_documents_content_type
          validate_documents_page_size
          find_poa_by_id

          # This job only occurs when a Representative submits a PoA request to ensure they've also uploaded a document.
          ClaimsApi::PoaUpdater.perform_async(@power_of_attorney.id) if header_request?

          @power_of_attorney.set_file_data!(documents.first, params[:doc_type])
          @power_of_attorney.status = 'submitted'
          @power_of_attorney.save!
          @power_of_attorney.reload

          # This job will trigger whether submission is from a Veteran or Representative when a document is sent.
          ClaimsApi::VBMSUploadJob.perform_async(@power_of_attorney.id)
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
        def active
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_using_identifier_and_source(header_md5: header_md5,
                                                                                          source_name: source_name)
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found') unless power_of_attorney

          if current_poa
            lighthouse_poa = power_of_attorney.attributes
            lighthouse_poa['current_poa'] = current_poa
            lighthouse_poa['form_data'] = power_of_attorney.form_data
            combined = ClaimsApi::PowerOfAttorney.new(lighthouse_poa)

            render json: combined, serializer: ClaimsApi::PowerOfAttorneySerializer
          else
            render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
          end
        end

        # POST to validate 2122 submission payload.
        #
        # @return [JSON] Success if valid, error messages if invalid.
        def validate
          add_deprecation_headers_to_response(response: response, link: ClaimsApi::EndpointDeprecation::V1_DEV_DOCS)
          validate_json_schema
          render json: validation_success
        end

        private

        def current_poa
          @current_poa ||= BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa
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
      end
    end
  end
end
