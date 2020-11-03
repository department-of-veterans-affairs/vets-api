# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'

module ClaimsApi
  module V1
    module Forms
      class PowerOfAttorneyController < ClaimsApi::BaseFormController
        include ClaimsApi::DocumentValidations

        before_action { permit_scopes %w[claim.write] }
        before_action :validate_json_schema, only: %i[submit_form_2122 validate]
        before_action :validate_documents_content_type, only: %i[upload]
        before_action :validate_documents_page_size, only: %i[upload]
        before_action :find_poa_by_id, only: %i[upload status]

        FORM_NUMBER = '2122'

        def submit_form_2122
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(header_md5: header_md5)
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
          ClaimsApi::PoaFormBuilderJob.perform_async(power_of_attorney.id) if data['signatureImages'].present?

          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        def upload
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

        def status
          render json: @power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        def active
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(header_md5: header_md5)
          if power_of_attorney
            render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
          else
            previous_poa = ClaimsApi::PowerOfAttorney.new(form_data: {}, current_poa: current_poa)
            render json: previous_poa, serializer: ClaimsApi::PowerOfAttorneySerializer
          end
        end

        def validate
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
            icn: current_user.icn,
            email: current_user.email
          }
        end

        def source_name
          user = header_request? ? @current_user : target_veteran
          "#{user.first_name} #{user.last_name}"
        end

        def find_poa_by_id
          @power_of_attorney = ClaimsApi::PowerOfAttorney.find_by id: params[:id]
          render_poa_not_found unless @power_of_attorney
        end

        def render_poa_not_found
          render json: { errors: [{ status: 404, detail: 'POA not found' }] }, status: :not_found
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
