# frozen_string_literal: true

require 'claim_letters/claim_letter_downloader'

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
      @service ||= ClaimStatusTool::ClaimLetterDownloader.new(@current_user, allowed_doctypes)
    end

    # 27: Board Of Appeals Decision Letter
    # 34: Correspondence
    # 184: Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)
    # 408: VA Examination Letter
    # 700: MAP-D Development letter
    # 704: Standard 5103 Notice
    # 706: 5103/DTA Letter
    # 858: Custom 5103 Notice
    # 859: Subsequent Development letter
    # 864: General Records Request (Medical)
    # 942: Final Attempt Letter
    # 1605: General Records Request (Non-Medical)
    def allowed_doctypes
      doctypes = %w[184]
      doctypes << '27' if Flipper.enabled?(:cst_include_ddl_boa_letters, @current_user)
      doctypes << '704' if Flipper.enabled?(:cst_include_ddl_5103_letters, @current_user)
      doctypes << '706' if Flipper.enabled?(:cst_include_ddl_5103_letters, @current_user)
      doctypes << '858' if Flipper.enabled?(:cst_include_ddl_5103_letters, @current_user)
      doctypes << '34' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '408' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '700' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '859' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '864' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '942' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '1605' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes
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
