# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Serializers
        module SupportingDocumentsSerializer
          def self.serialize(documents)
            documents.map do |doc|
              {
                'documentId' => doc.document_id,
                'documentTypeLabel' => doc.document_type_label,
                'originalFileName' => doc.original_file_name,
                'trackedItemId' => doc.tracked_item_id,
                'uploadDate' => doc.upload_date
              }
            end
          end
        end
      end
    end
  end
end
