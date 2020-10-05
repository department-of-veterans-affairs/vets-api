# frozen_string_literal: true

module VAForms
  module Forms
    class Form
      include Swagger::Blocks

      swagger_component do
        schema :FormsIndex do
          key :description, I18n.t('va_forms.endpoint_descriptions.index')
          property :id do
            key :description, 'JSON API identifier'
            key :type, :string
            key :example, 'VA10192'
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
              key :example, 'VA10192'
            end

            property :url do
              key :description, I18n.t('va_forms.field_descriptions.url')
              key :type, :string
              key :example, 'https://www.va.gov/vaforms/va/pdf/VA10192.pdf'
            end

            property :title do
              key :description, I18n.t('va_forms.field_descriptions.title')
              key :type, :string
              key :example, 'Information for Pre-Complaint Processing'
            end

            property :first_issued_on do
              key :description, I18n.t('va_forms.field_descriptions.first_issued_on')
              key :type, :string
              key :example, '2012-01-01'
              key :format, 'date'
            end

            property :last_revised_on do
              key :description, I18n.t('va_forms.field_descriptions.last_revised_on')
              key :type, :string
              key :example, '2012-01-01'
              key :format, 'date'
            end

            property :pages do
              key :description, I18n.t('va_forms.field_descriptions.pages')
              key :type, :integer
              key :example, 3
            end

            property :valid_pdf do
              key :description, I18n.t('va_forms.field_descriptions.valid_pdf')
              key :type, :boolean
              key :example, true
            end

            property :sha256 do
              key :description, I18n.t('va_forms.field_descriptions.sha256')
              key :type, :string
              key :example, '5fe171299ece147e8b456961a38e17f1391026f26e9e170229317bc95d9827b7'
            end
            property :form_usage do
              key :description, I18n.t('va_forms.field_descriptions.form_usage')
              key :type, :string
            end
            property :form_tool_intro do
              key :description, I18n.t('va_forms.field_descriptions.form_tool_intro')
              key :type, :string
            end
            property :form_tool_url do
              key :description, I18n.t('va_forms.field_descriptions.form_tool_url')
              key :type, :string
            end
            property :form_details_url do
              key :description, I18n.t('va_forms.field_descriptions.form_details_url')
              key :type, :string
            end
            property :form_type do
              key :description, I18n.t('va_forms.field_descriptions.form_type')
              key :type, :string
              key :example, 'VHA'
            end
            property :language do
              key :description, I18n.t('va_forms.field_descriptions.language')
              key :type, :string
              key :example, 'en'
            end
            property :deleted_at do
              key :description, I18n.t('va_forms.field_descriptions.deleted_at')
              key :type, :string
              key :example, '2018-07-30T17:31:15.958Z'
              key :format, 'date-time'
            end
            property :related_forms do
              key :description, I18n.t('va_forms.field_descriptions.related_forms')
              key :type, :array
              items do
                key :type, :string
                key :example, '21-22A'
              end
            end

            property :benefit_categories do
              key :description, I18n.t('va_forms.field_descriptions.benefit_categories')
              key :type, :array
              items do
                property :name do
                  key :description, I18n.t('va_forms.field_descriptions.benefit_category_name')
                  key :type, :string
                  key :example, 'Pension'
                end
                property :description do
                  key :description, I18n.t('va_forms.field_descriptions.benefit_category_description')
                  key :type, :string
                  key :example, 'VA pension benefits'
                end
              end
            end
          end
        end

        schema :FormShow do
          key :description, I18n.t('va_forms.endpoint_descriptions.show')
          property :id do
            key :description, 'JSON API identifier'
            key :type, :string
            key :example, 'VA10192'
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
              key :example, 'VA10192'
            end

            property :url do
              key :description, I18n.t('va_forms.field_descriptions.url')
              key :type, :string
              key :example, 'https://www.va.gov/vaforms/va/pdf/VA10192.pdf'
            end

            property :title do
              key :description, I18n.t('va_forms.field_descriptions.title')
              key :type, :string
              key :example, 'Information for Pre-Complaint Processing'
            end

            property :first_issued_on do
              key :description, I18n.t('va_forms.field_descriptions.first_issued_on')
              key :type, :string
              key :example, '2012-01-01'
              key :format, 'date'
            end

            property :last_revised_on do
              key :description, I18n.t('va_forms.field_descriptions.last_revised_on')
              key :type, :string
              key :example, '2012-01-01'
              key :format, 'date'
            end

            property :pages do
              key :description, I18n.t('va_forms.field_descriptions.pages')
              key :type, :integer
              key :example, 3
            end

            property :sha256 do
              key :description, I18n.t('va_forms.field_descriptions.sha256')
              key :type, :string
              key :example, '5fe171299ece147e8b456961a38e17f1391026f26e9e170229317bc95d9827b7'
            end

            property :form_usage do
              key :description, I18n.t('va_forms.field_descriptions.form_usage')
              key :type, :string
            end

            property :form_tool_intro do
              key :description, I18n.t('va_forms.field_descriptions.form_tool_intro')
              key :type, :string
            end

            property :form_tool_url do
              key :description, I18n.t('va_forms.field_descriptions.form_tool_url')
              key :type, :string
            end
            property :form_details_url do
              key :description, I18n.t('va_forms.field_descriptions.form_details_url')
              key :type, :string
            end
            property :form_type do
              key :description, I18n.t('va_forms.field_descriptions.form_type')
              key :type, :string
              key :example, 'VHA'
            end

            property :language do
              key :description, I18n.t('va_forms.field_descriptions.language')
              key :type, :string
              key :example, 'en'
            end

            property :related_forms do
              key :description, I18n.t('va_forms.field_descriptions.related_forms')
              key :type, :array
              items do
                key :type, :string
                key :example, '21-22A'
              end
            end

            property :benefit_categories do
              key :description, I18n.t('va_forms.field_descriptions.benefit_categories')
              key :type, :array
              items do
                property :name do
                  key :description, I18n.t('va_forms.field_descriptions.benefit_category_name')
                  key :type, :string
                  key :example, 'Pension'
                end
                property :description do
                  key :description, I18n.t('va_forms.field_descriptions.benefit_category_description')
                  key :type, :string
                  key :example, 'VA pension benefits'
                end
              end
            end

            property :versions do
              key :type, :array
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
