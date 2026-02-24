# frozen_string_literal: true

require 'form212680/monitor'

module V0
  class Form212680Controller < ApplicationController
    include RetriableConcern
    service_tag 'form-21-2680'
    before_action :check_feature_enabled

    # rubocop:disable Metrics/MethodLength
    def create
      claim = saved_claim_class.new(
        form: filtered_params,
        user_account_id: current_user&.user_account_uuid
      )

      monitor.track_submission_begun(claim, user_uuid: current_user&.uuid)

      if claim.save
        # NOTE: we are not calling process_attachments! because we are not submitting yet
        monitor.track_submission_success(claim, user_uuid: current_user&.uuid)

        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      else
        raise Common::Exceptions::ValidationErrors, claim
      end
    rescue Common::Exceptions::ValidationErrors => e
      # Track ActiveRecord validation errors
      monitor.track_request_validation_error(error: e, request:, claim:)
      monitor.track_submission_failure(claim, e, user_uuid: current_user&.uuid)
      raise
    rescue => e
      monitor.track_submission_failure(claim, e, user_uuid: current_user&.uuid)
      raise
    ensure
      monitor.track_request_code(response.status) if response.status
    end
    # rubocop:enable Metrics/MethodLength

    # get /v0/form212680/download_pdf/{guid}
    # Generate and download a pre-filled PDF with veteran sections (I-V) completed
    # Physician sections (VI-VIII) are left blank for manual completion
    #
    # rubocop:disable Metrics/MethodLength
    def download_pdf
      claim = saved_claim_class.find_by!(guid: params[:guid])
      pdf_start_time = Time.current

      source_file_path = with_retries('Generate 21-2680 PDF') do
        claim.generate_prefilled_pdf
      end

      unless source_file_path
        raise Common::Exceptions::InternalServerError,
              ArgumentError.new('Failed to generate PDF')
      end

      track_pdf_success(pdf_start_time)
      send_data File.read(source_file_path),
                filename: download_file_name(claim),
                type: 'application/pdf',
                disposition: 'attachment'
    rescue ActiveRecord::RecordNotFound
      raise Common::Exceptions::RecordNotFound, params[:guid]
    rescue => e
      StatsD.increment("#{stats_key}.pdf_generation.failure")
      handle_pdf_generation_error(e)
    ensure
      monitor.track_request_code(response.status) if response.status
      File.delete(source_file_path) if defined?(source_file_path) && source_file_path && File.exist?(source_file_path)
    end
    # rubocop:enable Metrics/MethodLength

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

    def monitor
      @monitor ||= Form212680::Monitor.new
    end

    def track_pdf_success(start_time)
      pdf_duration = Time.current - start_time
      StatsD.measure("#{stats_key}.pdf_generation.duration", pdf_duration * 1000)
      StatsD.increment("#{stats_key}.pdf_generation.success")
    end

    def check_feature_enabled
      routing_error unless Flipper.enabled?(:form_2680_enabled, current_user)
    end

    def handle_pdf_generation_error(error)
      Rails.logger.error(
        'Form212680: Error generating PDF',
        {
          form: '21-2680',
          guid: params[:guid],
          user_id: current_user&.uuid,
          error: error.message,
          backtrace: error.backtrace
        }
      )
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
