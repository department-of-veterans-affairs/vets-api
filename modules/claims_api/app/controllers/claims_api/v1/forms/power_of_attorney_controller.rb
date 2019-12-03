# frozen_string_literal: true

require_dependency 'claims_api/concerns/poa_verification'
require_dependency 'claims_api/concerns/page_size_validation'

module ClaimsApi
  module V1
    module Forms
      class PowerOfAttorneyController < ClaimsApi::BaseFormController
        include ClaimsApi::PageSizeValidation

        before_action { permit_scopes %w[claim.write] }
        before_action :validate_json_schema, only: %i[submit_form_2122]
        before_action :validate_documents_page_size, only: %i[upload]

        FORM_NUMBER = '2122'

        def submit_form_2122
          power_of_attorney = ClaimsApi::PowerOfAttorney.create(
            status: ClaimsApi::PowerOfAttorney::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes,
            source: source_name
          )
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(md5: power_of_attorney.md5) unless power_of_attorney.id
          power_of_attorney.save!

          ClaimsApi::PoaUpdater.perform_async(power_of_attorney.id)

          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        def upload
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(id: params[:id])
          power_of_attorney.set_file_data!(documents.first, params[:doc_type])
          power_of_attorney.status = 'submitted'
          power_of_attorney.save!
          power_of_attorney.reload
          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        def status
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(id: params[:id])
          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        private

        def source_name
          user = poa_request? ? @current_user : target_veteran
          "#{user.first_name} #{user.last_name}"
        end
      end
    end
  end
end
