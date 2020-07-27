# frozen_string_literal: true

module VaForms
  class FormListSerializer < ActiveModel::Serializer
    type :va_form

    attributes :form_name, :url, :title, :first_issued_on,
               :last_revision_on, :pages, :sha256

    def id
      object.form_name
    end
  end
end
