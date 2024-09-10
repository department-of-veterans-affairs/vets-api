module Swagger
  module Requests
    class PdfGenerator2122
      include Swagger::Blocks

      swagger_path '/representation_management/v0/pdf_generator_2122' do
        operation :post do
          key :summary, 'Generate a PDF for form 21-22'
          key :operationId, 'createPdfForm2122'
          key :produces, ['application/pdf']
          key :tags, ['PDF Generator 2122']

          parameter name: :pdf_generator2122 do
            key :in, :body
            key :description, 'Form data for generating PDF'
            key :required, true
            schema do
              key :type, :object
              property :organization_name do
                key :type, :string
                key :example, 'Veterans Organization'
              end
              property :record_consent do
                key :type, :boolean
                key :example, true
              end
              property :consent_limits do
                key :type, :string
                key :example, 'Limited to medical records'
              end
              property :consent_address_change do
                key :type, :boolean
                key :example, false
              end
              property :veteran do
                key :type, :object
                property :insurance_numbers do
                  key :type, :array
                  items do
                    key :type, :string
                  end
                  key :example, %w[123456789 987654321]
                end
              end
            end
          end

          response 200 do
            key :description, 'PDF generated successfully'
            content 'application/pdf' do
              schema do
                key :type, :string
                key :format, :binary
              end
            end
            header 'Content-Disposition' do
              key :type, :string
              key :example, 'attachment; filename="21-22.pdf"'
            end
          end

          response 422 do
            key :description, 'Unprocessable Entity'
            content 'application/json' do
              schema do
                key :type, :object
                property :errors do
                  key :type, :array
                  items do
                    key :type, :string
                  end
                  key :example, ["Organization name can't be blank", 'Record consent must be accepted']
                end
              end
            end
          end
        end
      end
    end
  end
end
