# frozen_string_literal: true

module VBADocuments
  module V1
    class UploadSerializer < VBADocuments::UploadSerializer
      delegate :status, to: :object

      def status
        object.status == 'error' ? raise(Common::Exceptions::RecordNotFound, object.guid) : object.status
      end
    end
  end
end
