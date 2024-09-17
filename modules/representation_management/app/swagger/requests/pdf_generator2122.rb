# frozen_string_literal: true

module Requests
  class PdfGenerator2122
    include Swagger::Blocks

    swagger_path '/representation_management/v0/pdf_generator_2122' do
      operation :post do
        key :summary, 'Generate a PDF for form 21-22'
        key :operationId, 'createPdfForm2122'
        key :produces, ['application/pdf']
        key :tags, ['PDF Generation']

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
            property :consent_address_change do
              key :type, :boolean
              key :example, false
            end
            property :consent_limits do
              key :type, :array
              items do
                key :type, :string
              end
              key :example, %w[ALCOHOLISM DRUG_ABUSE HIV SICKLE_CELL]
            end
            property :conditions_of_appointment do
              key :type, :array
              items do
                key :type, :string
              end
              key :example, %w[a123 b456 c789]
            end
            property :claimant do
              key :type, :object
              property :name do
                key :type, :object
                property :first do
                  key :type, :string
                  key :example, 'John'
                end
                property :middle do
                  key :type, :string
                  key :example, 'A'
                end
                property :last do
                  key :type, :string
                  key :example, 'Doe'
                end
              end
              property :address do
                key :type, :object
                property :address_line1 do
                  key :type, :string
                  key :example, '123 Main St'
                end
                property :address_line2 do
                  key :type, :string
                  key :example, 'Apt 1'
                end
                property :city do
                  key :type, :string
                  key :example, 'Springfield'
                end
                property :state_code do
                  key :type, :string
                  key :example, 'IL'
                end
                property :country do
                  key :type, :string
                  key :example, 'US'
                end
                property :zip_code do
                  key :type, :string
                  key :example, '62704'
                end
                property :zip_code_suffix do
                  key :type, :string
                  key :example, '1234'
                end
              end
              property :date_of_birth do
                key :type, :string
                key :format, :date
                key :example, '12/31/2000'
              end
              property :relationship do
                key :type, :string
                key :example, 'Spouse'
              end
              property :phone do
                key :type, :string
                key :example, '1234567890'
              end
              property :email do
                key :type, :string
                key :example, 'veteran@example.com'
              end
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
              property :name do
                key :type, :object
                property :first do
                  key :type, :string
                  key :example, 'John'
                end
                property :middle do
                  key :type, :string
                  key :example, 'A'
                end
                property :last do
                  key :type, :string
                  key :example, 'Doe'
                end
              end
              property :address do
                key :type, :object
                property :address_line1 do
                  key :type, :string
                  key :example, '123 Main St'
                end
                property :address_line2 do
                  key :type, :string
                  key :example, 'Apt 1'
                end
                property :city do
                  key :type, :string
                  key :example, 'Springfield'
                end
                property :state_code do
                  key :type, :string
                  key :example, 'IL'
                end
                property :country do
                  key :type, :string
                  key :example, 'US'
                end
                property :zip_code do
                  key :type, :string
                  key :example, '62704'
                end
                property :zip_code_suffix do
                  key :type, :string
                  key :example, '1234'
                end
              end
              property :ssn do
                key :type, :string
                key :example, '123456789'
              end
              property :va_file_number do
                key :type, :string
                key :example, '123456789'
              end
              property :date_of_birth do
                key :type, :string
                key :format, :date
                key :example, '12/31/2000'
              end
              property :service_number do
                key :type, :string
                key :example, '123456789'
              end
              property :service_branch do
                key :type, :string
                key :example, 'Army'
              end
              property :service_branch_other do
                key :type, :string
                key :example, 'Other Branch'
              end
              property :phone do
                key :type, :string
                key :example, '1234567890'
              end
              property :email do
                key :type, :string
                key :example, 'veteran@example.com'
              end
            end
          end
        end

        response 200 do
          key :description, 'PDF generated successfully'

          schema do
            property :data, type: :string, format: 'binary'
          end
        end

        response 422 do
          key :description, 'unprocessable entity response'
          schema do
            key :$ref, :Errors
          end
        end
      end
    end
  end
end
