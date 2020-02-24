# frozen_string_literal: true

module Swagger
  module Schemas
    class Forms
      include Swagger::Blocks

      swagger_schema :Forms do
        key :required, [:data]
        property :data, type: :array do
          items do
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

              property :last_revision_on do
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
        end
      end
    end
  end
end
