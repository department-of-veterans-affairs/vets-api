# frozen_string_literal: true

module V0
  class Form212680Controller < ApplicationController
    include RetriableConcern
    service_tag 'form-21-2680'
    skip_before_action :authenticate
    before_action :load_user
    before_action :check_feature_enabled

    def create
      claim = build_and_save_claim!
      handle_successful_claim(claim)

      clear_saved_form(claim.form_id)
      render json: SavedClaimSerializer.new(claim)
    rescue JSON::ParserError => e
      handle_json_parse_error(e)
    rescue => e
      handle_general_error(e, claim)
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
    rescue => e
      handle_pdf_generation_error(e)
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

    def handle_pdf_generation_error(error)
      Rails.logger.error('Form212680: Error generating PDF', error: error.message, backtrace: error.backtrace)
      render json: {
        errors: [{
          title: 'PDF Generation Failed',
          detail: 'An error occurred while generating the PDF',
          status: '500'
        }]
      }, status: :internal_server_error
    end

    def build_and_save_claim!
      claim = saved_claim_class.new(form: filtered_params)
      Rails.logger.info "Begin ClaimGUID=#{claim.guid} Form=#{claim.class::FORM} UserID=#{current_user&.uuid}"

      if claim.save
        # NOTE: we are not calling process_attachments! because we are not submitting yet
        claim
      else
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
    end

    def handle_successful_claim(claim)
      StatsD.increment("#{stats_key}.success")
      Rails.logger.info "Submitted job ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM} " \
                        "UserID=#{current_user&.uuid}"
    end

    def handle_json_parse_error(error)
      Rails.logger.error('Form212680: JSON parse error in form data', error: error.message)
      raise Common::Exceptions::ParameterMissing, 'form'
    end

    def handle_general_error(error, claim)
      Rails.logger.error(
        'Form212680: error submitting claim',
        { error: error.message, claim_errors: defined?(claim) && claim&.errors&.full_messages }
      )
      raise
    end
  end
end
