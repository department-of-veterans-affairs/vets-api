# frozen_string_literal: true

module VaForms
  class FormListSerializer < ActiveModel::Serializer
    type :va_form

    attributes :form_name, :url, :title, :first_issued_on,
               :last_revision_on, :pages, :sha256, :valid_pdf,
               :form_usage, :form_tool_intro, :form_tool_url, :form_details_url,
               :form_type, :language, :deleted_at, :related_forms, :benefit_categories

    def id
      object.form_name
    end
  end
end
