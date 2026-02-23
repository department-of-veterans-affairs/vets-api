# frozen_string_literal: true

require 'form210779/monitor'

module V0
  class Form210779Controller < ApplicationController
    include RetriableConcern
    service_tag 'nursing-home-information'
    skip_before_action :authenticate
    before_action :load_user
    before_action :check_feature_enabled

    def create
      claim = saved_claim_class.new(form: filtered_params)

      monitor.track_submission_begun(claim, user_uuid: current_user&.uuid)

      if claim.save
        claim.process_attachments!

        monitor.track_submission_success(claim, user_uuid: current_user&.uuid)

        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      else
        raise Common::Exceptions::ValidationErrors, claim
      end
    rescue Common::Exceptions::ValidationErrors
      monitor.track_submission_failure(claim, StandardError.new('Validation failed'), user_uuid: current_user&.uuid)
      monitor.track_request_code(422)
      raise
    rescue => e
      monitor.track_submission_failure(claim, e, user_uuid: current_user&.uuid)
      raise
    ensure
      monitor.track_request_code(response.status) if response.status
    end

    def download_pdf
      claim = saved_claim_class.find_by!(guid: params[:guid])
      pdf_start_time = Time.current

      source_file_path = with_retries('Generate 21-0779 PDF') { claim.to_pdf }

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

    private

    def track_pdf_success(start_time)
      pdf_duration = Time.current - start_time
      StatsD.measure("#{stats_key}.pdf_generation.duration", pdf_duration * 1000)
      StatsD.increment("#{stats_key}.pdf_generation.success")
    end

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

    def monitor
      @monitor ||= Form210779::Monitor.new
    end

    def check_feature_enabled
      routing_error unless Flipper.enabled?(:form_0779_enabled, current_user)
    end

    def handle_pdf_generation_error(error)
      Rails.logger.error(
        'Form210779: Error generating PDF',
        {
          form: '21-0779',
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
