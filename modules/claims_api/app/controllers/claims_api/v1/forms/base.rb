# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'claims_api/form_schemas'
require 'evss/disability_compensation_auth_headers'
require 'evss/auth_headers'
require 'claims_api/special_issue_mappers/bgs'

module ClaimsApi
  module V1
    module Forms
      class Base < ClaimsApi::V1::ApplicationController
        # schema endpoint should be wide open
        skip_before_action :authenticate, only: %i[schema]
        skip_before_action :validate_veteran_identifiers, only: %i[schema]
        include ClaimsApi::EndpointDeprecation

        def schema
          add_deprecation_headers_to_response(response: response, link: ClaimsApi::EndpointDeprecation::V1_DEV_DOCS)
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
          @documents ||= params.slice(*document_keys).values.map do |document|
            case document
            when String
              decode_document(document)
            when ActionDispatch::Http::UploadedFile
              document.original_filename = create_unique_filename(doc: document)
              document
            else
              document
            end
          end.compact
        end

        def decode_document(document)
          base64 = document.split(',').last
          decoded_data = Base64.decode64(base64)
          filename = "temp_upload_#{SecureRandom.urlsafe_base64(8)}.pdf"
          temp_file = Tempfile.new(filename, encoding: 'ASCII-8BIT')
          temp_file.write(decoded_data)
          temp_file.close
          ActionDispatch::Http::UploadedFile.new(filename: filename,
                                                 type: 'application/pdf',
                                                 tempfile: temp_file)
        end

        # We have no control over the names of the binary attachments that the consumer gives us.
        # Ensure each attachment we're given has a unique filename so we don't overwrite anything already stored in S3.
        # See API-15088 for context
        def create_unique_filename(doc:)
          original_filename = doc.original_filename
          file_extension = File.extname(original_filename)
          base_filename = File.basename(original_filename, file_extension)
          "#{base_filename}_#{SecureRandom.urlsafe_base64(8)}#{file_extension}"
        end

        def bgs_service
          bgs = BGS::Services.new(
            external_uid: target_veteran.participant_id,
            external_key: target_veteran.participant_id
          )
          ClaimsApi::Logger.log('poa', detail: 'bgs-ext service built')
          bgs
        end

        def local_bgs_service
          external_key = target_veteran.participant_id.to_s
          @local_bgs_service ||= ClaimsApi::LocalBGS.new(
            external_uid: external_key,
            external_key: external_key
          )
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
