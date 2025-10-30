# frozen_string_literal: true

class SavedClaimSerializer
  include JSONAPI::Serializer

  set_type :saved_claims

  attributes :submitted_at, :regional_office, :confirmation_number, :guid

  attribute :form, &:form_id

  attribute :pdfUrl, if: proc { |_record, params| params && params[:pdf_url].present? } do |_record, params|
    params[:pdf_url]
  end
end
