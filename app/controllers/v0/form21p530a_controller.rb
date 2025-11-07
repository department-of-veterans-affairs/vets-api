# frozen_string_literal: true

module V0
  class Form21p530aController < ApplicationController
    include RetriableConcern

    service_tag 'state-tribal-interment-allowance'
    skip_before_action :authenticate, only: %i[create download_pdf]

    def create
      # Body parsed by Rails; schema validated by committee before hitting here.
      payload = request.raw_post

      claim = SavedClaim::Form21p530a.new(form: payload)

      if claim.save
        claim.process_attachments!

        Rails.logger.info(
          "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
        )
        StatsD.increment("#{stats_key}.success")

        render json: SavedClaimSerializer.new(claim)
      else
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
    rescue => e
      # Include validation errors when present; helpful in logs/Sentry.
      Rails.logger.error(
        'Form21p530a: error submitting claim',
        { error: e.message, claim_errors: defined?(claim) && claim&.errors&.full_messages }
      )
      raise
    end

    def download_pdf
      # Parse raw JSON to get camelCase keys (bypasses OliveBranch transformation)
      parsed_form = JSON.parse(request.raw_post)

      source_file_path = with_retries('Generate 21P-530A PDF') do
        PdfFill::Filler.fill_ancillary_form(parsed_form, SecureRandom.uuid, '21P-530a')
      end

      # Stamp signature (SignatureStamper returns original path if signature is blank)
      source_file_path = PdfFill::Forms::Va21p530a.stamp_signature(source_file_path, parsed_form)

      client_file_name = "21P-530a_#{SecureRandom.uuid}.pdf"

      file_contents = File.read(source_file_path)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    rescue => e
      handle_pdf_generation_error(e)
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def handle_pdf_generation_error(error)
      Rails.logger.error('Form21p530a: Error generating PDF', error: error.message, backtrace: error.backtrace)
      render json: {
        errors: [{
          title: 'PDF Generation Failed',
          detail: 'An error occurred while generating the PDF',
          status: '500'
        }]
      }, status: :internal_server_error
    end

    def stats_key
      'api.form21p530a'
    end
  end
end
