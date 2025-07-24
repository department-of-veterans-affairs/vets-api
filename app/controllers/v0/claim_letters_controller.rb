# frozen_string_literal: true

require 'claim_letters/claim_letter_downloader'
require 'claim_letters/providers/claim_letters/lighthouse_claim_letters_provider'

module V0
  class ClaimLettersController < ApplicationController
    Sentry.set_tags(feature: 'claim-letters')
    service_tag 'claim-status'

    def index
      docs = service.get_letters
      log_metadata_to_datadog(docs)

      render json: docs
    end

    def show
      document_id = CGI.unescape(params[:document_id])

      service.get_letter(document_id) do |data, mime_type, disposition, filename|
        send_data(data, type: mime_type, disposition:, filename:)
      end
    end

    private

    def service
      use_lighthouse = Flipper.enabled?(:cst_claim_letters_use_lighthouse_api_provider, @current_user)
      api_provider = use_lighthouse ? 'lighthouse' : 'VBMS'
      ::Rails.logger.info('Choosing Claim Letters API Provider via cst_claim_letters_use_lighthouse_api_provider',
                          { message_type: 'cst.api_provider',
                            api_provider: })
      if use_lighthouse
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
  end
end
