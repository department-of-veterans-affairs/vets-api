# frozen_string_literal: true

module Vye
  module BatchTransfer
    module IngressFiles
      TimsLineExtraction = Struct.new(:row, :profile, :pending_document) do
        def initialize(row:)
          super(row:, profile: nil, pending_document: nil)

          extract_profile
          extract_pending_document
        end

        private

        def extract_profile
          list = %i[ssn file_number]
          self.profile = row.to_h.slice(*list)
        end

        def extract_pending_document
          list = %i[doc_type queue_date rpo]
          queue_date = DateTime.strptime(row[:queue_date], '%m/%d/%y')
          attributes = row.to_h.slice(*list).merge(queue_date:)
          self.pending_document = attributes
        end

        public

        def records
          raise 'invalid extraction' if [profile, pending_document].any?(&:blank?)

          { profile:, pending_document: }
        end
      end
    end
  end
end
