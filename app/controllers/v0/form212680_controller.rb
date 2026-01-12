# frozen_string_literal: true

module V0
  class Form212680Controller < ApplicationController
    include RetriableConcern
    service_tag 'form-21-2680'
    skip_before_action :authenticate
    before_action :load_user
    before_action :check_feature_enabled

    def create
      claim = saved_claim_class.new(form: filtered_params)
      Rails.logger.info "Begin ClaimGUID=#{claim.guid} Form=#{claim.class::FORM} UserID=#{current_user&.uuid}"
      if claim.save
        # NOTE: we are not calling process_attachments! because we are not submitting yet
        StatsD.increment("#{stats_key}.success")
        Rails.logger.info "Submitted job ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM} " \
                          "UserID=#{current_user&.uuid}"
        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      else
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
    rescue JSON::ParserError
      raise Common::Exceptions::ParameterMissing, 'form'
    end

    # get /v0/form212680/download_pdf/{guid}
    # Generate and download a pre-filled PDF with veteran sections (I-V) completed
    # Physician sections (VI-VIII) are left blank for manual completion
    #
    def download_pdf
      claim = saved_claim_class.find_by!(guid: params[:guid])
      source_file_path = with_retries('Generate 21-2680 PDF') do
        claim.generate_prefilled_pdf
      end
      raise Common::Exceptions::InternalServerError, 'Failed to generate PDF' unless source_file_path

      send_data File.read(source_file_path),
                filename: download_file_name(claim),
                type: 'application/pdf',
                disposition: 'attachment'
    rescue ActiveRecord::RecordNotFound
      raise Common::Exceptions::RecordNotFound, params[:guid]
    ensure
      File.delete(source_file_path) if defined?(source_file_path) && source_file_path && File.exist?(source_file_path)
    end

    private

    def short_name
      'house_bound_status_claim'
    end

    def filtered_params
      params.require(:form)
    end

    def download_file_name(claim)
      "21-2680_#{claim.veteran_first_last_name.gsub(' ', '_')}.pdf"
    end

    def saved_claim_class
      SavedClaim::Form212680
    end

    def stats_key
      'api.form212680'
    end

    def check_feature_enabled
      routing_error unless Flipper.enabled?(:form_2680_enabled, current_user)
    end
  end
end
