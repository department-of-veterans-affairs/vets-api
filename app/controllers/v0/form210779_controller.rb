# frozen_string_literal: true

module V0
  class Form210779Controller < ApplicationController
    include RetriableConcern
    service_tag 'nursing-home-information'
    skip_before_action :authenticate
    before_action :load_user
    before_action :check_feature_enabled

    def create
      claim = saved_claim_class.new(form: filtered_params)
      Rails.logger.info "Begin ClaimGUID=#{claim.guid} Form=#{claim.class::FORM} UserID=#{current_user&.uuid}"
      if claim.save
        claim.process_attachments!

        StatsD.increment("#{stats_key}.success")
        Rails.logger.info "Submitted job ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM} " \
                          "UserID=#{current_user&.uuid}"

        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      else
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
    rescue JSON::ParserError => e
      Rails.logger.error('Form210779: JSON parse error in form data', error: e.message)
      raise Common::Exceptions::ParameterMissing, 'form'
    rescue => e
      Rails.logger.error(
        'Form210779: error submitting claim',
        { error: e.message, claim_errors: defined?(claim) && claim&.errors&.full_messages }
      )
      raise
    end

    def download_pdf
      claim = saved_claim_class.find_by!(guid: params[:guid])
      source_file_path = with_retries('Generate 21-0779 PDF') do
        claim.to_pdf
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

    def filtered_params
      params.require(:form)
    end

    def download_file_name(claim)
      "21-0779_#{claim.veteran_name.gsub(' ', '_')}.pdf"
    end

    def saved_claim_class
      SavedClaim::Form210779
    end

    def stats_key
      'api.form210779'
    end

    def check_feature_enabled
      routing_error unless Flipper.enabled?(:form_0779_enabled, current_user)
    end

    def handle_pdf_generation_error(error)
      Rails.logger.error('Form210779: Error generating PDF', error: error.message, backtrace: error.backtrace)
      render json: {
        errors: [{
          title: 'PDF Generation Failed',
          detail: 'An error occurred while generating the PDF',
          status: '500'
        }]
      }, status: :internal_server_error
    end
  end
end
