# frozen_string_literal: true

module ClaimsApi
  class SupportingDocumentUploader < ClaimsApi::BaseUploader
    def location
      'disability_compensation'
    end
  end
end
