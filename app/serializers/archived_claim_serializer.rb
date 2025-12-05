# frozen_string_literal: true

class ArchivedClaimSerializer < SavedClaimSerializer
  attribute :pdf_url, if: proc { |_record, params| params && params[:pdf_url].present? } do |_record, params|
    params[:pdf_url]
  end
end
