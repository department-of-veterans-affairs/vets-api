# frozen_string_literal: true

# Temporary stub implementation for Form 21-0779 to enable parallel frontend development
# This entire file will be replaced with the full implementation in Phase 1

module V0
  class Form210779Controller < ApplicationController
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
      # stubbed - returns a static pdf for now
      # pdf_path = claim.generate_prefilled_pdf
      pdf_path = 'lib/pdf_fill/forms/pdfs/21-0779.pdf'
      pdf_content = File.read(pdf_path)

      # file_name_for_pdf(parsed_form, field, form_prefix)

      send_data pdf_content,
                filename: "21-0779_#{SecureRandom.uuid}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    end

    private

    def stats_key
      'api.form210779'
    end
  end
end
