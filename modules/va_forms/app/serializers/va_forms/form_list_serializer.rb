# frozen_string_literal: true

module VAForms
  class FormListSerializer < ActiveModel::Serializer
    type :va_form

    attributes :form_name, :url, :title, :first_issued_on,
               :last_revision_on, :pages, :sha256, :last_sha256_change, :valid_pdf,
               :form_usage, :form_tool_intro, :form_tool_url, :form_details_url,
               :form_type, :language, :deleted_at, :related_forms, :benefit_categories,
               :va_form_administration

    def id
      object.row_id
    end
  end
end
