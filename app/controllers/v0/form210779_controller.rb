# frozen_string_literal: true

# Temporary stub implementation for Form 21-0779 to enable parallel frontend development
# This entire file will be replaced with the full implementation in Phase 1

module V0
  class Form210779Controller < ApplicationController
    service_tag 'nursing-home-information'
    skip_before_action :authenticate

    def create
      # using request.raw_post to avoid the middleware that transforms the JSON keys to snake case
      claim = SavedClaim::Form210779.new(form: request.raw_post)

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
        'Form210779: error submitting claim',
        { error: e.message, claim_errors: defined?(claim) && claim&.errors&.full_messages }
      )
      raise
    end

    def download_pdf
      claim = SavedClaim::Form210779.find_by(guid: params[:guid])
      source_file_path = claim.to_pdf

      send_data File.read(source_file_path),
                filename: "21-0779_#{SecureRandom.uuid}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def stats_key
      'api.form210779'
    end
  end
end
