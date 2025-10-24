# frozen_string_literal: true

module V0
  class Form214192Controller < ApplicationController
    include RetriableConcern

    service_tag 'employment-information'
    skip_before_action :authenticate, only: %i[create download_pdf]

    before_action :feature_enabled?
    before_action :record_submission_attempt, only: :create

    def create
      claim = SavedClaim::Form214192.new(form: form_params.to_json)

      if claim.save
        claim.process_attachments!

        Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"

        render json: SavedClaimSerializer.new(claim)
      else
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
    rescue => e
      Rails.logger.error('Form214192: error submitting claim', { error: e.message })
      raise e
    end

    def download_pdf
      parsed_form = JSON.parse(params[:form])

      source_file_path = with_retries('Generate 21-4192 PDF') do
        PdfFill::Filler.fill_ancillary_form(parsed_form, SecureRandom.uuid, '21-4192')
      end

      client_file_name = "21-4192_#{SecureRandom.uuid}.pdf"

      file_contents = File.read(source_file_path)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def feature_enabled?
      raise Common::Exceptions::RoutingError unless Flipper.enabled?(:form_4192_enabled)
    end

    def record_submission_attempt
      StatsD.increment("#{stats_key}.submission_attempt")
    end

    def form_params
      params.require(:form)
    end

    def stats_key
      'api.form214192'
    end
  end
end
