# frozen_string_literal: true

require 'jsonapi/parser'

module ClaimsApi
  module V0
    module Forms
      class PowerOfAttorneyController < ClaimsApi::V0::Forms::Base
        include ClaimsApi::DocumentValidations
        include ClaimsApi::EndpointDeprecation

        FORM_NUMBER = '2122'

        # POST to change power of attorney for a Veteran.
        #
        # @return [JSON] Record in pending state
        def submit_form_2122
          validate_json_schema

          power_of_attorney = ClaimsApi::PowerOfAttorney.find_using_identifier_and_source(header_md5: header_md5,
                                                                                          source_name: source_name)
          unless power_of_attorney&.status&.in?(%w[submitted pending])
            power_of_attorney = ClaimsApi::PowerOfAttorney.create(
              status: ClaimsApi::PowerOfAttorney::PENDING,
              auth_headers: auth_headers,
              form_data: form_attributes,
              source_data: source_data,
              header_md5: header_md5
            )

            unless power_of_attorney.persisted?
              power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(md5: power_of_attorney.md5)
            end

            power_of_attorney.save!
          end

          ClaimsApi::PoaUpdater.perform_async(power_of_attorney.id)

          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        # PUT to upload a wet-signed 2122 form.
        # Required if "signatures" not supplied in above POST.
        #
        # @return [JSON] Claim record
        def upload
          validate_documents_content_type
          validate_documents_page_size

          power_of_attorney = ClaimsApi::PowerOfAttorney.find_using_identifier_and_source(id: params[:id],
                                                                                          source_name: source_name)
          power_of_attorney.set_file_data!(documents.first, params[:doc_type])
          power_of_attorney.status = 'submitted'
          power_of_attorney.save!
          power_of_attorney.reload
          ClaimsApi::VBMSUploadJob.perform_async(power_of_attorney.id)
          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        # GET the current status of a previous POA change request.
        #
        # @return [JSON] POA record with current status
        def status
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_using_identifier_and_source(id: params[:id],
                                                                                          source_name: source_name)
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found') unless power_of_attorney

          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        # GET current POA for a Veteran.
        #
        # @return [JSON] Last POA change request through Claims API
        def active
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_using_identifier_and_source(header_md5: header_md5,
                                                                                          source_name: source_name)
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found') unless power_of_attorney

          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        # POST to validate 2122 submission payload.
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

        def header_md5
          @header_md5 ||= Digest::MD5.hexdigest(auth_headers.except('va_eauth_authenticationauthority',
                                                                    'va_eauth_service_transaction_id',
                                                                    'va_eauth_issueinstant',
                                                                    'Authorization').to_json)
        end

        def source_data
          {
            name: source_name,
            icn: Settings.bgs.external_uid,
            email: Settings.bgs.external_key
          }
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
