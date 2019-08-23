# frozen_string_literal: true

module VBADocuments
  module V1
    class UploadSerializer < VBADocuments::UploadSerializer
      delegate :status, to: :object
    end
  end
end
