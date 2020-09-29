# frozen_string_literal: true

module BGS
  class UploadedDocumentService < BaseService
    def get_documents
      # rubocop:disable Rails/DynamicFindBy
      @service.uploaded_document.find_by_participant_id(@user.participant_id)
      # rubocop:enable Rails/DynamicFindBy
    rescue => e
      report_error(e)
    end
  end
end
