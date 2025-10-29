# frozen_string_literal: true

module V0
  class Form214192Controller < ApplicationController
    service_tag 'employment-information'
    skip_before_action :authenticate, only: %i[create download_pdf]
    skip_before_action :verify_authenticity_token

    def create
      # Body parsed by Rails; schema validated by committee before hitting here.
      payload = request.request_parameters

      puts "payload: #{payload}" * 100

      claim = SavedClaim::Form214192.new(form: payload.to_json)

      if claim.save
        claim.process_attachments!

        Rails.logger.info(
          "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
        )

        render json: SavedClaimSerializer.new(claim)
      else
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
    rescue => e
      # Include validation errors when present; helpful in logs/Sentry.
      Rails.logger.error(
        'Form214192: error submitting claim',
        { error: e.message, claim_errors: (defined?(claim) && claim&.errors&.full_messages) }
      )
      raise
    end

    def download_pdf
      render json: {
        message: 'PDF download stub - not yet implemented'
      }, status: :ok
    end
  end
end
