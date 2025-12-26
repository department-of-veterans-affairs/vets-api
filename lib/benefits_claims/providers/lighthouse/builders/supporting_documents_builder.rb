# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Builders
        module SupportingDocumentsBuilder
          def self.build(documents_data)
            return nil if documents_data.nil?
            return [] if documents_data.empty?

            documents_data.map do |doc_data|
              BenefitsClaims::Responses::SupportingDocument.new(
                document_id: doc_data['documentId'],
                document_type_label: doc_data['documentTypeLabel'],
                original_file_name: doc_data['originalFileName'],
                tracked_item_id: doc_data['trackedItemId'],
                upload_date: doc_data['uploadDate']
              )
            end
          end
        end
      end
    end
  end
end
