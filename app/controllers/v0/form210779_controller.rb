# frozen_string_literal: true

module V0
  class Form210779Controller < ApplicationController
    include RetriableConcern
    include PdfFilenameGenerator

    service_tag 'nursing-home-information'
    skip_before_action :authenticate

    def create
      params.require(:form)

      claim = SavedClaim::Form210779.new(form: params[:form].to_json)

      if claim.save
        # claim.process_attachments!

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
        'Form210779: error submitting claim',
        { error: e.message, claim_errors: defined?(claim) && claim&.errors&.full_messages }
      )
      raise
    end

    def download_pdf
      parsed_form = request.request_parameters

      source_file_path = with_retries('Generate 21-0779 PDF') do
        PdfFill::Filler.fill_ancillary_form(parsed_form, SecureRandom.uuid, '21-0779')
      end

      client_file_name = "21-0779_#{SecureRandom.uuid}.pdf"

      file_contents = File.read(source_file_path)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    rescue => e
      handle_pdf_generation_error(e)
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def handle_pdf_generation_error(error)
      Rails.logger.error('Form210779: Error generating PDF', error: error.message, backtrace: error.backtrace)
      render json: {
        errors: [{
          title: 'PDF Generation Failed',
          detail: 'An error occurred while generating the PDF',
          status: '500'
        }]
      }, status: :internal_server_error
    end

    def stats_key
      'api.form210779'
    end
  end
end
