# frozen_string_literal: true

module VBADocuments
  module V2
    class UploadSerializer < VBADocuments::UploadSerializer
      delegate :status, to: :object

      def attributes(fields)
        attrs = super
        attrs.delete(:location)
        attrs
      end
    end
  end
end
