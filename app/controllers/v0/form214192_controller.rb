# frozen_string_literal: true

module V0
  class Form214192Controller < ApplicationController
    include RetriableConcern

    service_tag 'employment-information'
    skip_before_action :authenticate, only: %i[create download_pdf]
    before_action :load_user, :check_feature_enabled

    def create
      # Body parsed by Rails; schema validated by committee before hitting here.
      payload = request.raw_post

      claim = SavedClaim::Form214192.new(form: payload)

      if claim.save
        claim.process_attachments!

        Rails.logger.info(
          "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
        )
        StatsD.increment("#{stats_key}.success")

        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      else
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
    rescue => e
      # Include validation errors when present; helpful in logs/Sentry.
      Rails.logger.error(
        'Form214192: error submitting claim',
        { error: e.message, claim_errors: defined?(claim) && claim&.errors&.full_messages }
      )
      raise
    end

    def download_pdf
      # Parse raw JSON to get camelCase keys (bypasses OliveBranch transformation)
      parsed_form = JSON.parse(request.raw_post)

      source_file_path = with_retries('Generate 21-4192 PDF') do
        PdfFill::Filler.fill_ancillary_form(parsed_form, SecureRandom.uuid, '21-4192')
      end

      # Stamp signature (SignatureStamper returns original path if signature is blank)
      source_file_path = PdfFill::Forms::Va214192.stamp_signature(source_file_path, parsed_form)

      client_file_name = "21-4192_#{SecureRandom.uuid}.pdf"

      file_contents = File.read(source_file_path)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    rescue => e
      handle_pdf_generation_error(e)
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def check_feature_enabled
      routing_error unless Flipper.enabled?(:form_4192_enabled, current_user)
    end

    def handle_pdf_generation_error(error)
      Rails.logger.error('Form214192: Error generating PDF', error: error.message, backtrace: error.backtrace)
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
  end
end
