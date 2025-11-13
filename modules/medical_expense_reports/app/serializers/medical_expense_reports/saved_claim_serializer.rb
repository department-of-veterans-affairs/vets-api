# frozen_string_literal: true

module MedicalExpenseReports
  class SavedClaimSerializer < SavedClaimSerializer
    attribute :pdfUrl, if: proc { |_record, params| params && params[:pdf_url].present? } do |_record, params|
      params[:pdf_url]
    end
  end
end