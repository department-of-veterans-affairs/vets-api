# frozen_string_literal: true

require 'claim_letters/claim_letter_downloader'
require 'claim_letters/providers/claim_letters/lighthouse_claim_letters_provider'

module V0
  class ClaimLettersController < ApplicationController
    before_action :set_api_provider

    Sentry.set_tags(feature: 'claim-letters')
    service_tag 'claim-status'

    VBMS_LIGHTHOUSE_MIGRATION_STATSD_KEY_PREFIX = 'vbms_lighthouse_claim_letters_provider_error'

    def index
      docs = service.get_letters
      log_metadata_to_datadog(docs)

      render json: docs
    rescue => e
      log_api_provider_error(e)
      raise e
    end

    def show
      document_id = CGI.unescape(params[:document_id])

      service.get_letter(document_id) do |data, mime_type, disposition, filename|
        send_data(data, type: mime_type, disposition:, filename:)
      end
    rescue => e
      log_api_provider_error(e)
      raise e
    end

    private

    def set_api_provider
      @use_lighthouse = Flipper.enabled?(:cst_claim_letters_use_lighthouse_api_provider, @current_user)
      @api_provider = @use_lighthouse ? 'lighthouse' : 'VBMS'
    end

    def service
      ::Rails.logger.info('Choosing Claim Letters API Provider via cst_claim_letters_use_lighthouse_api_provider',
                          { message_type: 'cst.api_provider',
                            api_provider: @api_provider,
                            action: action_name })
      Datadog::Tracing.active_trace&.set_tag('api_provider', @api_provider)
      if @use_lighthouse
        LighthouseClaimLettersProvider.new(@current_user)
      else
        ClaimStatusTool::ClaimLetterDownloader.new(@current_user)
      end
    end

    def log_metadata_to_datadog(docs)
      docs_metadata = []
      docs.each do |d|
        docs_metadata << { doc_type: d[:doc_type], type_description: d[:type_description] }
      end
      ::Rails.logger.info('DDL Document Types Metadata',
                          { message_type: 'ddl.doctypes_metadata',
                            document_type_metadata: docs_metadata })
    end

    def log_api_provider_error(error)
      metric_key = "#{VBMS_LIGHTHOUSE_MIGRATION_STATSD_KEY_PREFIX}.#{action_name}.#{@api_provider}"
      StatsD.increment(metric_key)
      ::Rails.logger.info("#{metric_key} error", {
                            message_type: 'cst.api_provider.error',
                            error_type: error.class.to_s,
                            error_backtrace: error.backtrace&.first(3),
                            api_provider: @api_provider,
                            action: action_name
                          })
    end
  end
end
