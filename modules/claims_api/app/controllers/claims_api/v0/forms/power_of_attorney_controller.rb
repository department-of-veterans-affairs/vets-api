# frozen_string_literal: true

require_dependency 'claims_api/base_form_controller'
require_dependency 'claims_api/concerns/document_validations'
require 'jsonapi/parser'

module ClaimsApi
  module V0
    module Forms
      class PowerOfAttorneyController < ClaimsApi::BaseFormController
        include ClaimsApi::DocumentValidations

        FORM_NUMBER = '2122'

        skip_before_action(:authenticate)
        before_action :validate_json_schema, only: %i[submit_form_2122 validate]
        before_action :validate_documents_content_type, only: %i[upload]
        before_action :validate_documents_page_size, only: %i[upload]

        def submit_form_2122
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(header_md5: header_md5)
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

        def upload
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(id: params[:id])
          power_of_attorney.set_file_data!(documents.first, params[:doc_type])
          power_of_attorney.status = 'submitted'
          power_of_attorney.save!
          power_of_attorney.reload
          ClaimsApi::VbmsUploadJob.perform_async(power_of_attorney.id)
          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        def status
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(id: params[:id])
          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        def active
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(header_md5: header_md5)
          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        def validate
          render json: validation_success
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
            name: request.headers['X-Consumer-Username'],
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
