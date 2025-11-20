# frozen_string_literal: true

module DebtsApi
  module V0
    class OneDebtLetterService
      STATS_KEY = 'api.one_debt_letter'

      def initialize(user)
        @user = user
      end

      def get_pdf(document)
        raise ArgumentError, 'Document is required' unless document

        combine_pdfs(document)
      end

      def combine_pdfs(document)
        legalese_pdf = load_legalese_pdf
        combined_pdf = CombinePDF.parse(document.read) << legalese_pdf
        combined_pdf.to_pdf
      rescue => e
        Rails.logger.error("Failed to combine PDFs: #{e.message}")
        StatsD.increment("#{STATS_KEY}.error")
        raise e
      end

      private

      def load_legalese_pdf
        legalese_path = Rails.root.join(
          'modules', 'debts_api', 'app', 'assets', 'documents', 'one_debt_letter_legal_content.pdf'
        )

        CombinePDF.load(legalese_path)
      end
    end
  end
end
