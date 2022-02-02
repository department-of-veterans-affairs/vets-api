# frozen_string_literal: true

module VAForms
  module Forms
    class FormSwagger
      include Swagger::Blocks

      swagger_component do
        schema :FormsIndex do
          key :description, I18n.t('va_forms.endpoint_descriptions.index')
          property :id do
            key :description, 'JSON API identifier'
            key :type, :string
            key :example, '5403'
          end
          property :type do
            key :description, 'JSON API type specification'
            key :type, :string
            key :example, 'va_form'
          end
          property :attributes do
            property :form_name do
              key :description, I18n.t('va_forms.field_descriptions.form_name')
              key :type, :string
              key :example, '10-10EZ'
            end
            property :url do
              key :description, I18n.t('va_forms.field_descriptions.url')
              key :type, :string
              key :example, 'https://www.va.gov/vaforms/medical/pdf/10-10EZ-fillable.pdf'
            end
            property :title do
              key :description, I18n.t('va_forms.field_descriptions.title')
              key :type, :string
              key :example, 'Instructions and Enrollment Application for Health Benefits'
            end
            property :first_issued_on do
              key :description, I18n.t('va_forms.field_descriptions.first_issued_on')
              key :type, :string
              key :nullable, true
              key :example, '2016-07-10'
              key :format, 'date'
            end
            property :last_revision_on do
              key :description, I18n.t('va_forms.field_descriptions.last_revision_on')
              key :type, :string
              key :nullable, true
              key :example, '2020-01-17'
              key :format, 'date'
            end
            property :pages do
              key :description, I18n.t('va_forms.field_descriptions.pages')
              key :type, :integer
              key :example, 5
            end
            property :sha256 do
              key :description, I18n.t('va_forms.field_descriptions.sha256')
              key :type, :string
              key :nullable, true
              key :example, '6e6465e2e1c89225871daa9b6d86b92d1c263c7b02f98541212af7b35272372b'
            end
            property :last_sha256_change do
              key :description, I18n.t('va_forms.field_descriptions.last_sha256_change')
              key :type, :string
              key :nullable, true
              key :example, '2019-05-30'
              key :format, 'date'
            end
            property :valid_pdf do
              key :description, I18n.t('va_forms.field_descriptions.valid_pdf')
              key :type, :boolean
              key :example, 'true'
            end
            property :form_usage do
              key :description, I18n.t('va_forms.field_descriptions.form_usage')
              key :type, :string
              key :nullable, true
              key :example, '<p>Use VA Form 10-10EZ if you’re a Veteran and want to apply for VA health care. You must be enrolled in...</p>'
            end
            property :form_tool_intro do
              key :description, I18n.t('va_forms.field_descriptions.form_tool_intro')
              key :type, :string
              key :nullable, true
              key :example, 'You can apply online instead of filling out and sending us the paper form.'
            end
            property :form_tool_url do
              key :description, I18n.t('va_forms.field_descriptions.form_tool_url')
              key :type, :string
              key :nullable, true
              key :example, 'https://www.va.gov/health-care/apply/application/introduction'
            end
            property :form_details_url do
              key :description, I18n.t('va_forms.field_descriptions.form_details_url')
              key :type, :string
              key :nullable, true
              key :example, 'https://www.va.gov/find-forms/about-form-10-10ez'
            end
            property :form_type do
              key :description, I18n.t('va_forms.field_descriptions.form_type')
              key :type, :string
              key :nullable, true
              key :example, 'benefit'
            end
            property :language do
              key :description, I18n.t('va_forms.field_descriptions.language')
              key :type, :string
              key :example, 'en'
            end
            property :deleted_at do
              key :description, I18n.t('va_forms.field_descriptions.deleted_at')
              key :type, :string
              key :nullable, true
              key :example, 'null'
              key :format, 'date-time'
            end
            property :related_forms do
              key :description, I18n.t('va_forms.field_descriptions.related_forms')
              key :type, :array
              key :nullable, true
              items do
                key :type, :string
                key :example, '10-10EZR'
              end
            end
            property :benefit_categories do
              key :description, I18n.t('va_forms.field_descriptions.benefit_categories')
              key :type, :array
              key :nullable, true
              items do
                property :name do
                  key :description, I18n.t('va_forms.field_descriptions.benefit_category_name')
                  key :type, :string
                  key :example, 'Health care'
                end
                property :description do
                  key :description, I18n.t('va_forms.field_descriptions.benefit_category_description')
                  key :type, :string
                  key :example, 'VA health care'
                end
              end
            end
            property :va_form_administration do
              key :description, I18n.t('va_forms.field_descriptions.va_form_administration')
              key :type, :string
              key :nullable, true
              key :example, 'Veterans Health Administration'
            end
          end
        end

        schema :FormShow do
          key :description, I18n.t('va_forms.endpoint_descriptions.show')
          property :id do
            key :description, 'JSON API identifier'
            key :type, :string
            key :example, '10-10-EZ'
          end
          property :type do
            key :description, 'JSON API type specification'
            key :type, :string
            key :example, 'va_form'
          end
          property :attributes do
            property :form_name do
              key :description, I18n.t('va_forms.field_descriptions.form_name')
              key :type, :string
              key :example, '10-10EZ'
            end
            property :url do
              key :description, I18n.t('va_forms.field_descriptions.url')
              key :type, :string
              key :example, 'https://www.va.gov/vaforms/medical/pdf/10-10EZ-fillable.pdf'
            end
            property :title do
              key :description, I18n.t('va_forms.field_descriptions.title')
              key :type, :string
              key :example, 'Instructions and Enrollment Application for Health Benefits'
            end
            property :first_issued_on do
              key :description, I18n.t('va_forms.field_descriptions.first_issued_on')
              key :type, :string
              key :nullable, true
              key :example, '2016-07-10'
              key :format, 'date'
            end
            property :last_revision_on do
              key :description, I18n.t('va_forms.field_descriptions.last_revision_on')
              key :type, :string
              key :nullable, true
              key :example, '2020-01-17'
              key :format, 'date'
            end
            property :created_at do
              key :description, I18n.t('va_forms.field_descriptions.created_at')
              key :type, :string
              key :nullable, true
              key :example, '2021-03-30T16:28:30.338Z'
              key :format, 'date-time'
            end
            property :pages do
              key :description, I18n.t('va_forms.field_descriptions.pages')
              key :type, :integer
              key :example, 5
            end
            property :sha256 do
              key :description, I18n.t('va_forms.field_descriptions.sha256')
              key :type, :string
              key :nullable, true
              key :example, '5fe171299ece147e8b456961a38e17f1391026f26e9e170229317bc95d9827b7'
            end
            property :valid_pdf do
              key :description, I18n.t('va_forms.field_descriptions.valid_pdf')
              key :type, :boolean
              key :example, 'true'
            end
            property :form_usage do
              key :description, I18n.t('va_forms.field_descriptions.form_usage')
              key :type, :string
              key :nullable, true
              key :example, '<p>Use VA Form 10-10EZ if you’re a Veteran and want to apply for VA health care. You must be enrolled in...</p>'
            end
            property :form_tool_intro do
              key :description, I18n.t('va_forms.field_descriptions.form_tool_intro')
              key :type, :string
              key :nullable, true
              key :example, 'You can apply online instead of filling out and sending us the paper form.'
            end
            property :form_tool_url do
              key :description, I18n.t('va_forms.field_descriptions.form_tool_url')
              key :type, :string
              key :nullable, true
              key :example, 'https://www.va.gov/health-care/apply/application/introduction'
            end
            property :form_details_url do
              key :description, I18n.t('va_forms.field_descriptions.form_details_url')
              key :type, :string
              key :nullable, true
              key :example, 'https://www.va.gov/find-forms/about-form-10-10ez'
            end
            property :form_type do
              key :description, I18n.t('va_forms.field_descriptions.form_type')
              key :type, :string
              key :nullable, true
              key :example, 'benefit'
            end
            property :language do
              key :description, I18n.t('va_forms.field_descriptions.language')
              key :type, :string
              key :nullable, true
              key :example, 'en'
            end
            property :deleted_at do
              key :description, I18n.t('va_forms.field_descriptions.deleted_at')
              key :nullable, true
              key :type, :string
              key :example, nil
              key :format, 'date-time'
            end
            property :related_forms do
              key :description, I18n.t('va_forms.field_descriptions.related_forms')
              key :type, :array
              key :nullable, true
              items do
                key :type, :string
                key :example, '10-10EZR'
              end
            end
            property :benefit_categories do
              key :description, I18n.t('va_forms.field_descriptions.benefit_categories')
              key :type, :array
              key :nullable, true
              items do
                property :name do
                  key :description, I18n.t('va_forms.field_descriptions.benefit_category_name')
                  key :type, :string
                  key :example, 'Health care'
                end
                property :description do
                  key :description, I18n.t('va_forms.field_descriptions.benefit_category_description')
                  key :type, :string
                  key :example, 'VA health care'
                end
              end
            end
            property :va_form_administration do
              key :description, I18n.t('va_forms.field_descriptions.va_form_administration')
              key :type, :string
              key :nullable, true
              key :example, 'Veterans Health Administration'
            end
            property :versions do
              key :type, :array
              key :nullable, true
              key :description, I18n.t('va_forms.field_descriptions.versions')
              items do
                property :sha256 do
                  key :description, I18n.t('va_forms.field_descriptions.version_sha256')
                  key :type, :string
                  key :example, '5fe171299ece147e8b456961a38e17f1391026f26e9e170229317bc95d9827b7'
                end
                property :revision_on do
                  key :description, I18n.t('va_forms.field_descriptions.version_revised_on')
                  key :type, :string
                  key :example, '2012-01-01'
                  key :format, 'date'
                end
              end
            end
          end
        end
      end
    end
  end
end
