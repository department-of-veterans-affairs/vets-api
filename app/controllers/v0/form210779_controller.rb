# frozen_string_literal: true

module V0
  class Form210779Controller < ApplicationController
    service_tag 'nursing-home-information'
    skip_before_action :authenticate
    before_action :load_user
    before_action :check_feature_enabled

    def create
      # using request.raw_post to avoid the middleware that transforms the JSON keys to snake case
      claim = SavedClaim::Form210779.new(form: request.raw_post)
      Rails.logger.info "Begin ClaimGUID=#{claim.guid} Form=#{claim.class::FORM} UserID=#{current_user&.uuid}"
      if claim.save
        claim.process_attachments!

        StatsD.increment("#{stats_key}.success")
        Rails.logger.info "Submitted job ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM} " \
                          "UserID=#{current_user&.uuid}"
        render json: SavedClaimSerializer.new(claim)
      else
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
    rescue JSON::ParserError
      raise Common::Exceptions::ParameterMissing, 'form'
    rescue => e
      # Include validation errors when present; helpful in logs/Sentry.
      Rails.logger.error(
        'Form210779: error submitting claim',
        { error: e.message, claim_errors: defined?(claim) && claim&.errors&.full_messages }
      )
      raise
    end

    def download_pdf
      claim = SavedClaim::Form210779.find_by!(guid: params[:guid])
      source_file_path = claim.to_pdf
      raise Common::Exceptions::InternalServerError, 'Failed to generate PDF' unless source_file_path

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

    def check_feature_enabled
      routing_error unless Flipper.enabled?(:form_0779_enabled, current_user)
    end
  end
end
