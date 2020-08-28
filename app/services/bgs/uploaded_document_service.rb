# frozen_string_literal: true

module BGS
  class UploadedDocumentService < BaseService
    def get_documents
      @service.uploaded_document.find_by_participant_id(@user.participant_id)
    rescue => e
      report_error(e)
    end
  end
end
