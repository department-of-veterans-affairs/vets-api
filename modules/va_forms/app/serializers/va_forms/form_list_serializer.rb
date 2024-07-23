# frozen_string_literal: true

module VAForms
  class FormListSerializer
    include JSONAPI::Serializer

    set_type :va_form
    set_id :row_id

    attributes :form_name, :url, :title, :first_issued_on,
               :last_revision_on, :pages, :sha256, :last_sha256_change, :valid_pdf,
               :form_usage, :form_tool_intro, :form_tool_url, :form_details_url,
               :form_type, :language, :deleted_at, :related_forms, :benefit_categories,
               :va_form_administration
  end
end
