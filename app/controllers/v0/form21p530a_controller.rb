# frozen_string_literal: true

module V0
  class Form21p530aController < ApplicationController
    include RetriableConcern

    service_tag 'state-tribal-interment-allowance'
    skip_before_action :authenticate, only: %i[create download_pdf]

    def create
      # Body parsed by Rails; schema validated by committee before hitting here.
      payload = request.request_parameters

      claim = SavedClaim::Form21p530a.new(form: payload.to_json)

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
      # TODO: Implement PDF generation when PdfFill::Forms::Va21p530a is available
      # This will be implemented in a separate PR after PDF generation is merged
      render json: {
        message: 'PDF download not yet implemented'
      }, status: :ok
    end

    private

    def stats_key
      'api.form21p530a'
    end
  end
end
