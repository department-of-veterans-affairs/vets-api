# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'claims_api/form_schemas'
require 'evss/disability_compensation_auth_headers'
require 'evss/auth_headers'
require 'claims_api/special_issue_mappers/bgs'

module ClaimsApi
  module V0
    module Forms
      class Base < ClaimsApi::V0::ApplicationController
        include ClaimsApi::EndpointDeprecation

        skip_before_action :verify_mpi, only: %i[schema]

        # Returns acceptable json schema for POST submission endpoints.
        #
        # @return [JSON] Schema for each form submission.
        def schema
          add_deprecation_headers_to_response(response: response, link: ClaimsApi::EndpointDeprecation::V0_DEV_DOCS)
          render json: { data: [ClaimsApi::FormSchemas.new.schemas[self.class::FORM_NUMBER]] }
        end

        private

        def validate_json_schema
          validator = ClaimsApi::FormSchemas.new
          validator.validate!(self.class::FORM_NUMBER, form_attributes)
        end

        def form_attributes
          @json_body.dig('data', 'attributes') || {}
        end

        def auth_headers
          evss_headers = EVSS::DisabilityCompensationAuthHeaders
                         .new(target_veteran(with_gender: true))
                         .add_headers(
                           EVSS::AuthHeaders.new(target_veteran(with_gender: true)).to_h
                         )

          if request.headers['Mock-Override'] &&
             Settings.claims_api.disability_claims_mock_override
            evss_headers['Mock-Override'] = request.headers['Mock-Override']
            Rails.logger.info('ClaimsApi: Mock Override Engaged')
          end

          evss_headers
        end

        def documents
          document_keys = params.keys.select { |key| key.include? 'attachment' }
          params.slice(*document_keys).values.map do |document|
            if document.is_a?(String)
              decode_document(document)
            else
              document
            end
          end.compact
        end

        def decode_document(document)
          base64 = document.split(',').last
          decoded_data = Base64.decode64(base64)
          filename = "temp_upload_#{Time.zone.now.to_i}.pdf"
          temp_file = Tempfile.new(filename, encoding: 'ASCII-8BIT')
          temp_file.write(decoded_data)
          temp_file.close
          ActionDispatch::Http::UploadedFile.new(filename: filename,
                                                 type: 'application/pdf',
                                                 tempfile: temp_file)
        end

        def received_date
          form_attributes['received_date']
        end

        def target_veteran_name
          "#{target_veteran.first_name} #{target_veteran.last_name}"
        end
      end
    end
  end
end
