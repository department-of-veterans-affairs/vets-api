# frozen_string_literal: true

module VAForms
  class FormDetailSerializer < ActiveModel::Serializer
    type :va_form

    attributes :form_name, :url, :title, :first_issued_on,
               :last_revision_on, :created_at, :pages, :sha256, :valid_pdf,
               :form_usage, :form_tool_intro, :form_tool_url, :form_details_url,
               :form_type, :language, :deleted_at, :related_forms,
               :benefit_categories, :va_form_administration, :versions

    def id
      object.row_id
    end

    def versions
      object.versions.map do |v|
        if v.changeset.present?
          {
            sha256: v.changeset['sha256']&.last,
            revision_on: v.created_at&.strftime('%Y-%m-%d')
          }
        end
      end
    end
  end
end
