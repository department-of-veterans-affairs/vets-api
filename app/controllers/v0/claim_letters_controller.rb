# frozen_string_literal: true

require 'claim_letters/claim_letter_downloader'

module V0
  class ClaimLettersController < ApplicationController
    Sentry.set_tags(feature: 'claim-letters')
    service_tag 'claim-status'

    def index
      docs = service.get_letters

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
    # 184: Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)
    # 65: Standard 5103 Notice
    # 68: 5103/DTA Letter
    def allowed_doctypes
      doctypes = %w[184]
      doctypes << '27' if Flipper.enabled?(:cst_include_ddl_boa_letters, @current_user)
      doctypes << '704' if Flipper.enabled?(:cst_include_ddl_5103_letters, @current_user)
      doctypes << '706' if Flipper.enabled?(:cst_include_ddl_5103_letters, @current_user)
      doctypes << '858' if Flipper.enabled?(:cst_include_ddl_5103_letters, @current_user)
      doctypes
    end
  end
end
