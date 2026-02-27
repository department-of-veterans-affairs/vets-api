# frozen_string_literal: true

require 'form21p530a/monitor'

module V0
  class Form21p530aController < ApplicationController
    include RetriableConcern
    include PdfFill::Forms::FormHelper

    service_tag 'state-tribal-interment-allowance'
    skip_before_action :authenticate, only: %i[create download_pdf]
    before_action :load_user, :check_feature_enabled

    def create
      claim = build_claim
      monitor.track_submission_begun(claim, user_uuid: current_user&.uuid)

      if claim.save
        claim.process_attachments!
        monitor.track_submission_success(claim, user_uuid: current_user&.uuid)
        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      else
        raise Common::Exceptions::ValidationErrors, claim
      end
    rescue => e
      monitor.track_submission_failure(claim, e, user_uuid: current_user&.uuid)
      raise
    ensure
      track_response_code('create', claim)
    end

    def download_pdf
      pdf_start_time = Time.current
      parsed_form = parse_and_transform_payload
      source_file_path = generate_and_stamp_pdf(parsed_form)

      monitor.track_pdf_generation_success(pdf_start_time)

      client_file_name = "21P-530a_#{SecureRandom.uuid}.pdf"
      file_contents = File.read(source_file_path)
      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    rescue Common::Exceptions::ValidationErrors
      raise
    rescue => e
      handle_pdf_generation_error(e)
    ensure
      track_response_code('download_pdf')
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def check_feature_enabled
      routing_error unless Flipper.enabled?(:form_530a_enabled, current_user)
    end

    def stats_key
      'api.form21p530a'
    end

    def transform_country_codes(payload)
      parsed = JSON.parse(payload)
      address = parsed.dig('burialInformation', 'recipientOrganization', 'address')
      if address&.key?('country')
        transformed_country = extract_country(address)
        if transformed_country
          validate_country_code!(transformed_country)
          address['country'] = transformed_country
        end
      end
      parsed.to_json
    end

    def validate_country_code!(country_code)
      return if country_code.blank?

      IsoCountryCodes.find(country_code)
    rescue IsoCountryCodes::UnknownCodeError
      claim = SavedClaim::Form21p530a.new
      claim.errors.add '/burialInformation/recipientOrganization/address/country',
                       "'#{country_code}' is not a valid country code"
      raise Common::Exceptions::ValidationErrors, claim
    end

    def build_claim
      payload = request.raw_post
      transformed_payload = transform_country_codes(payload)
      SavedClaim::Form21p530a.new(form: transformed_payload)
    end

    def parse_and_transform_payload
      raw_payload = request.raw_post
      transformed_payload = transform_country_codes(raw_payload)
      JSON.parse(transformed_payload)
    end

    def generate_and_stamp_pdf(parsed_form)
      source_file_path = with_retries('Generate 21P-530A PDF') do
        PdfFill::Filler.fill_ancillary_form(parsed_form, SecureRandom.uuid, '21P-530A')
      end
      PdfFill::Forms::Va21p530a.stamp_signature(source_file_path, parsed_form)
    end

    def track_response_code(action, claim = nil)
      return unless response.status

      monitor.track_request_code(
        response.status,
        action:,
        user_uuid: current_user&.uuid,
        claim_guid: claim&.guid
      )
    end

    def monitor
      @monitor ||= Form21p530a::Monitor.new
    end

    def handle_pdf_generation_error(error)
      monitor.track_pdf_generation_failure(error)
      render json: {
        errors: [{
          title: 'PDF Generation Failed',
          detail: 'An error occurred while generating the PDF',
          status: '500'
        }]
      }, status: :internal_server_error
    end
  end
end
