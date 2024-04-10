# frozen_string_literal: true

module Swagger
  module Requests
    class FinancialStatusReports
      include Swagger::Blocks

      swagger_path '/debts_api/v0/financial_status_reports' do
        operation :post do
          key :summary, 'Submits Form VA-5655 data to the Debt Management Center'
          key :description, "Submits Form VA-5655 to the Debt Management Center.
            The data is ingested by DMC's Financial Status Report API, where it is
            then used to fill a PDF version of the VA-5655 form, which gets submitted
            to filenet."
          key :operationId, 'postFinancialStatusReport'
          key :tags, %w[financial_status_reports]

          parameter do
            key :name, :request
            key :in, :body
            key :required, true
            schema '$ref': :FinancialStatusReport
          end

          response 200 do
            key :description, 'Form VA-5655 Financial Status Report successful submission'

            schema do
              property :content, type: :string
            end
          end
        end
      end

      swagger_path '/debts_api/v0/financial_status_reports/download_pdf' do
        operation :get do
          key :summary, 'Downloads the filled copy of VA-5655 Financial Status Report'
          key :operationId, 'getFinancialStatusReport'
          key :tags, %w[financial_status_reports]

          response 200 do
            key :description, 'Financial Status Report download'

            schema do
              property :data, type: :string, format: 'binary'
            end
          end
        end
      end
    end
  end
end
