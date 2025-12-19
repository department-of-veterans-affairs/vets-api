# frozen_string_literal: true

module V0
  class Form214192Controller < ApplicationController
    include RetriableConcern

    service_tag 'employment-information'
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
      # When we have time to change the front end, we should reference the claim created in in the create action
      # and make this a get request that takes the guid of the saved claim
      claim = build_claim

      source_file_path = with_retries('Generate 21-4192 PDF') do
        PdfFill::Filler.fill_ancillary_form(claim.parsed_form, SecureRandom.uuid, '21-4192')
      end

      # Stamp signature (SignatureStamper returns original path if signature is blank)
      source_file_path = PdfFill::Forms::Va214192.stamp_signature(source_file_path, claim.parsed_form)

      client_file_name = "21-4192_#{SecureRandom.uuid}.pdf"

      file_contents = File.read(source_file_path)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def build_claim
      # we're bypassing OliveBranch middleware here to preserve camelCase keys
      payload = request.raw_post
      claim = SavedClaim::Form214192.new(form: payload)
      raise Common::Exceptions::ValidationErrors, claim unless claim.valid?

      claim
    end

    def check_feature_enabled
      routing_error unless Flipper.enabled?(:form_4192_enabled, current_user)
    end

    def stats_key
      'api.form214192'
    end
  end
end
