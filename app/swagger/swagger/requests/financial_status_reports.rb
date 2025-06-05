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

      swagger_path '/debts_api/v0/financial_status_reports/submissions' do
        operation :get do
          key :summary, 'Returns all Financial Status Report submissions for the current user'
          key :description, 'Retrieves a list of all FSR (VA Form 5655) submissions for the authenticated user,
            ordered by most recent first.'
          key :operationId, 'getFinancialStatusReportSubmissions'
          key :tags, %w[financial_status_reports]

          response 200 do
            key :description, 'Financial Status Report submissions list'

            schema do
              property :submissions, type: :array do
                items do
                  property :id, type: :string, description: 'Submission UUID'
                  property :created_at, type: :string, format: 'date-time', description: 'Submission creation timestamp'
                  property :updated_at, type: :string, format: 'date-time', description: 'Last update timestamp'
                  property :state, type: :string, enum: %w[unassigned in_progress submitted failed],
                                   description: 'Current state of the submission'
                  property :metadata, type: :object do
                    property :debt_type, type: :string, enum: %w[DEBT COPAY],
                                         description: 'Type of debt included in the submission'
                    property :streamlined, type: :object, description: 'Streamlined waiver information' do
                      property :value, type: :boolean, description: 'Whether this is a streamlined submission'
                      property :type, type: :string, enum: %w[short long], description: 'Type of streamlined submission'
                    end
                    property :combined, type: :boolean,
                                        description: 'Whether submission includes both VBA debts and VHA copays'
                    property :debt_identifiers, type: :array,
                                                description: 'Array of unique identifiers for debts/copays ' \
                                                             'to help detect duplicate submissions' do
                      items do
                        key :type, :string
                        key :description,
                            'For VBA debts: composite ID (deductionCode + originalAR). For VHA copays: UUID'
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
