# frozen_string_literal: true

module VaForms
  class FormModelSwagger
    include Swagger::Blocks

    swagger_schema :FormsIndex do
      key :description, 'A listing of all the VA Forms and their last revision date'

      property :id do
        key :type, :string
        key :example, '10388-1'
        key :description, 'Form name issued by VA'
      end

      property :type do
        key :type, :string
        key :example, 'va_forms'
        key :description, 'Required by JSON API standard'
      end

      property :attributes do
        key :type, :object
        key :description, 'Required by JSON API standard'

        property :form_name do
          key :type, :string
          key :example, 'SF-33'
          key :description, 'Name given to the form by the VA'
        end

        property :url do
          key :type, :string
          key :example, 'http://www.gsa.gov/portal/forms/download/116254'
          key :description, 'Location where the form can be downloaded from'
        end

        property :title do
          key :type, :string
          key :example, 'Solicitation, Offer and Award'
          key :description, 'Title of the form given by the VA'
        end

        property :pages do
          key :type, :integer
          key :example, 2
          key :description, 'Number of pages in the form'
        end

        property :issued_on do
          key :type, :string
          key :format, 'date'
          key :example, '2018-06-04'
          key :description, 'Date in YYYY-MM-DD the form was first issued'
        end

        property :last_revision_on do
          key :type, :string
          key :format, 'date'
          key :example, '2018-06-04'
          key :description, 'Date in YYYY-MM-DD for the last revision of the form'
        end
      end
    end

    swagger_schema :FormsShow do
      key :description, 'A listing of all the VA Forms and their last revision date'

      property :id do
        key :type, :string
        key :example, '10388-1'
        key :description, 'Form name issued by VA'
      end

      property :type do
        key :type, :string
        key :example, 'va_forms'
        key :description, 'Required by JSON API standard'
      end

      property :attributes do
        key :type, :object
        key :description, 'Required by JSON API standard'

        property :form_name do
          key :type, :string
          key :example, 'SF-33'
          key :description, 'Name given to the form by the VA'
        end

        property :url do
          key :type, :string
          key :example, 'http://www.gsa.gov/portal/forms/download/116254'
          key :description, 'Location where the form can be downloaded from'
        end

        property :title do
          key :type, :string
          key :example, 'Solicitation, Offer and Award'
          key :description, 'Title of the form given by the VA'
        end

        property :pages do
          key :type, :integer
          key :example, 2
          key :description, 'Number of pages in the form'
        end

        property :issued_on do
          key :type, :string
          key :format, 'date'
          key :example, '2018-06-04'
          key :description, 'Date in YYYY-MM-DD the form was first issued'
        end

        property :last_revision_on do
          key :type, :string
          key :format, 'date'
          key :example, '2018-06-04'
          key :description, 'Date in YYYY-MM-DD for the last revision of the form'
        end

        property :versions do
          key :type, :object

          property :sha256 do
            key :type, :string
            key :example, '5fe171299ece147e8b456961a38e17f1391026f26e9e170229317bc95d9827b7'
            key :description, 'sha256 of the revision'
          end

          property :revision_on do
            key :type, :string
            key :format, 'date'
            key :example, '2018-06-04'
            key :description, 'Date in YYYY-MM-DD of the revision'
          end
        end
      end
    end
  end
end
