# frozen_string_literal: true

module VaForms
  module Forms
    class Form
      include Swagger::Blocks

      swagger_component do
        schema :FormsIndex do
          key :description, 'A listing of available VA forms and their location.'
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
              key :description, 'Name of the VA Form'
              key :type, :string
              key :example, 'VA10192'
            end

            property :url do
              key :description, 'Web location of the form'
              key :type, :string
              key :example, 'https://www.va.gov/vaforms/va/pdf/VA10192.pdf'
            end

            property :title do
              key :description, 'Title of the form as given by VA'
              key :type, :string
              key :example, 'Information for Pre-Complaint Processing'
            end

            property :first_issued_on do
              key :description, 'The date the form first became available'
              key :type, :string
              key :example, '2012-01-01'
              key :format, 'date'
            end

            property :last_revised_on do
              key :description, 'The date the form was last updated'
              key :type, :string
              key :example, '2012-01-01'
              key :format, 'date'
            end

            property :pages do
              key :description, 'Number of pages contained in the form'
              key :type, :integer
              key :example, 3
            end

            property :sha256 do
              key :description, 'A sha256 hash of the form contents'
              key :type, :string
              key :example, '5fe171299ece147e8b456961a38e17f1391026f26e9e170229317bc95d9827b7'
            end
          end
        end

        schema :FormShow do
          key :description, 'Data for a particular VA form, including form version history.'
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
              key :description, 'Name of the VA Form'
              key :type, :string
              key :example, 'VA10192'
            end

            property :url do
              key :description, 'Web location of the form'
              key :type, :string
              key :example, 'https://www.va.gov/vaforms/va/pdf/VA10192.pdf'
            end

            property :title do
              key :description, 'Title of the form as given by VA'
              key :type, :string
              key :example, 'Information for Pre-Complaint Processing'
            end

            property :first_issued_on do
              key :description, 'The date the form first became available'
              key :type, :string
              key :example, '2012-01-01'
              key :format, 'date'
            end

            property :last_revised_on do
              key :description, 'The date the form was last updated'
              key :type, :string
              key :example, '2012-01-01'
              key :format, 'date'
            end

            property :pages do
              key :description, 'Number of pages contained in the form'
              key :type, :integer
              key :example, 3
            end

            property :sha256 do
              key :description, 'A sha256 hash of the form contents'
              key :type, :string
              key :example, '5fe171299ece147e8b456961a38e17f1391026f26e9e170229317bc95d9827b7'
            end
            property :versions do
              key :type, :array
              key :description, 'The version history of revisions to the form'
              items do
                property :sha256 do
                  key :description, 'A sha256 hash of the form contents for that version'
                  key :type, :string
                  key :example, '5fe171299ece147e8b456961a38e17f1391026f26e9e170229317bc95d9827b7'
                end

                property :revision_on do
                  key :description, 'The version was revised'
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
