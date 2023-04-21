# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class DecisionLetters
        def parse(decision_letters)
          return [] if decision_letters.empty?

          if Flipper.enabled?(:mobile_filter_doc_27_decision_letters_out)
            decision_letters.reject! { |letter| letter[:doc_type] == '27' }
          end

          decision_letters.map do |letter|
            create_decision_letter(letter)
          end.sort_by(&:received_at).reverse!
        end

        def create_decision_letter(letter)
          Mobile::V0::DecisionLetter.new(
            document_id: letter[:document_id],
            series_id: letter[:series_id],
            version: letter[:version],
            type_description: letter[:type_description],
            type_id: letter[:type_id],
            doc_type: letter[:doc_type],
            subject: letter[:subject],
            received_at: letter[:received_at].iso8601,
            source: letter[:source],
            mime_type: letter[:mime_type],
            alt_doc_types: letter[:alt_doc_types],
            restricted: letter[:restricted],
            upload_date: letter[:upload_date]&.iso8601
          )
        end
      end
    end
  end
end
