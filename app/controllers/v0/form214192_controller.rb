# frozen_string_literal: true

require 'form214192/monitor'

module V0
  class Form214192Controller < ApplicationController
    include RetriableConcern

    service_tag 'employment-information'
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
    rescue Common::Exceptions::ValidationErrors
      monitor.track_submission_failure(claim, StandardError.new('Validation failed'), user_uuid: current_user&.uuid)
      raise
    rescue => e
      monitor.track_submission_failure(claim, e, user_uuid: current_user&.uuid)
      raise
    ensure
      track_response_code('create', claim)
    end

    def download_pdf
      pdf_start_time = Time.current
      parsed_form = JSON.parse(request.raw_post)
      source_file_path = generate_and_stamp_pdf(parsed_form)

      monitor.track_pdf_generation_success(pdf_start_time)

      client_file_name = "21-4192_#{SecureRandom.uuid}.pdf"
      file_contents = File.read(source_file_path)
      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    rescue => e
      handle_pdf_generation_error(e)
    ensure
      track_response_code('download_pdf')
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def check_feature_enabled
      routing_error unless Flipper.enabled?(:form_4192_enabled, current_user)
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

    def stats_key
      'api.form214192'
    end

    def monitor
      @monitor ||= Form214192::Monitor.new
    end

    def build_claim
      payload = request.raw_post
      SavedClaim::Form214192.new(form: payload)
    end

    def generate_and_stamp_pdf(parsed_form)
      source_file_path = with_retries('Generate 21-4192 PDF') do
        PdfFill::Filler.fill_ancillary_form(parsed_form, SecureRandom.uuid, '21-4192')
      end
      PdfFill::Forms::Va214192.stamp_signature(source_file_path, parsed_form)
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
  end
end
