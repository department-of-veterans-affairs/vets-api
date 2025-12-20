# frozen_string_literal: true

module V0
  class Form21p530aController < ApplicationController
    include RetriableConcern

    service_tag 'state-tribal-interment-allowance'
    skip_before_action :authenticate, only: %i[create download_pdf]
    before_action :load_user, :check_feature_enabled

    def create
      claim = build_claim

      claim.save!
      claim.process_attachments!

      Rails.logger.info("ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}")
      StatsD.increment("#{stats_key}.success")

      clear_saved_form(claim.form_id)
      render json: SavedClaimSerializer.new(claim)
    rescue
      # app/controllers/concerns/exception_handling.rb will log the error and handle error responses
      # so we can just increment the metric here
      StatsD.increment("#{stats_key}.failure")
      raise
    end

    def download_pdf
      # When we have time to change the front end, we should reference the claim created in the create action
      # and make this a get request that takes the guid of the saved claim
      claim = build_claim

      source_file_path = with_retries('Generate 21P-530A PDF') do
        PdfFill::Filler.fill_ancillary_form(claim.parsed_form, SecureRandom.uuid, '21P-530a')
      end

      # Stamp signature (SignatureStamper returns original path if signature is blank)
      source_file_path = PdfFill::Forms::Va21p530a.stamp_signature(source_file_path, claim.parsed_form)

      client_file_name = "21P-530a_#{SecureRandom.uuid}.pdf"

      file_contents = File.read(source_file_path)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def check_feature_enabled
      routing_error unless Flipper.enabled?(:form_530a_enabled, current_user)
    end

    def stats_key
      'api.form21p530a'
    end

    def build_claim
      # Body parsed by Rails; schema validation is performed via claim.valid? below.
      payload = request.raw_post
      claim = SavedClaim::Form21p530a.new(form: payload)
      raise Common::Exceptions::ValidationErrors, claim unless claim.valid?

      claim
    end
  end
end
