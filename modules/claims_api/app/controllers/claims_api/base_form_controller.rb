# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'claims_api/form_schemas'
require 'evss/disability_compensation_auth_headers'
require 'evss/auth_headers'
require 'bgs/auth_headers'

module ClaimsApi
  class BaseFormController < ClaimsApi::ApplicationController
    # schema endpoint should be wide open
    skip_before_action :authenticate, only: %i[schema]
    skip_before_action :verify_mpi, only: %i[schema]

    def schema
      render json: { data: [ClaimsApi::FormSchemas.new.schemas[self.class::FORM_NUMBER]] }
    end

    private

    def validate_json_schema
      validator = ClaimsApi::FormSchemas.new
      validator.validate!(self.class::FORM_NUMBER, form_attributes)
    rescue JsonSchema::JsonApiMissingAttribute => e
      render json: e.to_json_api, status: e.code
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
      evss_headers = evss_headers.merge(BGS::AuthHeaders.new(@current_user).to_h) if @current_user.present?

      if request.headers['Mock-Override'] &&
         Settings.claims_api.disability_claims_mock_override
        evss_headers['Mock-Override'] = request.headers['Mock-Override']
        Rails.logger.info('ClaimsApi: Mock Override Engaged')
      end

      evss_headers
    end

    def flashes
      initial_flashes = form_attributes.dig('veteran', 'flashes')
      homelessness = form_attributes.dig('veteran', 'homelessness')
      is_terminally_ill = form_attributes.dig('veteran', 'isTerminallyIll')

      initial_flashes.push('Homeless') if homelessness.present?
      initial_flashes.push('Terminally Ill') if is_terminally_ill.present? && is_terminally_ill

      initial_flashes.present? ? initial_flashes.uniq : []
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

    def bgs_service
      BGS::Services.new(
        external_uid: target_veteran.participant_id,
        external_key: target_veteran.participant_id
      )
    end

    def intent_to_file_options
      {
        intent_to_file_type_code: ClaimsApi::IntentToFile::ITF_TYPES[form_type],
        participant_claimant_id: form_attributes['participant_claimant_id'] || participant_claimant_id,
        participant_vet_id: form_attributes['participant_vet_id'] || target_veteran.participant_id,
        received_date: v0? && received_date ? received_date : Time.zone.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
        submitter_application_icn_type_code: ClaimsApi::IntentToFile::SUBMITTER_CODE,
        ssn: target_veteran.ssn
      }
    end

    def participant_claimant_id
      if form_type == 'burial'
        begin
          @current_user.participant_id
        rescue ArgumentError
          raise ::Common::Exceptions::Forbidden, detail: "Representative cannot file for type 'burial'"
        end
      else
        target_veteran.participant_id
      end
    end

    def received_date
      form_attributes['received_date']
    end

    def target_veteran_name
      "#{target_veteran.first_name} #{target_veteran.last_name}"
    end

    def itf_not_found
      { errors: [{ detail: "No Intent to file is on record for #{target_veteran_name} of type #{active_param}" }] }
    end
  end
end
