# frozen_string_literal: true

module ClaimLetters
  module Utils
    module LetterTransformer
      FILENAME = 'ClaimLetter'

      def self.allowed?(doc, allowed_doctypes)
        allowed_doctypes.include?(doc[:doc_type] || doc['docTypeId'].to_s)
      end

      def self.filter_boa(doc)
        # Return true (don't filter) if received_at is nil
        return true if doc[:received_at].nil?

        # Filter out BOA documents (type 27) received less than 2 days ago
        return false if doc[:doc_type] == '27' && Time.zone.today - doc[:received_at].to_date < 2

        true
      end

      def self.decorate_description(doc_type)
        ClaimLetters::Responses::DOCTYPE_TO_TYPE_DESCRIPTION[doc_type]
      end

      def self.filename_with_date(filedate)
        "#{FILENAME}-#{filedate.year}-#{filedate.month}-#{filedate.day}.pdf"
      end
    end
  end
end
