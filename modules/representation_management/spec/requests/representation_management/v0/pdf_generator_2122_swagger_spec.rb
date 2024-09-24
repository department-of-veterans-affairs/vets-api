# frozen_string_literal: true

require 'swagger_helper'
require_relative '../../../support/swagger_shared_components/v0'

RSpec.describe 'PDF Generator 21-22', type: :request do
  path '/representation_management/v0/pdf_generator2122' do
    post('Generate a PDF for form 21-22') do
      tags 'PDF Generation'
      consumes 'application/json'
      produces 'application/pdf'
      operationId 'createPdfForm2122'
      # summary 'Generate a PDF for form 21-22'

      parameter SwaggerSharedComponents::V0.body_examples[:pdf_generator2122_parameter]

      response '200', 'PDF generated successfully' do
        let(:pdf_generator2122) { SwaggerSharedComponents::V0.body_examples[:pdf_generator2122] }
        run_test!
      end

      response '422', 'unprocessable entity response' do
        let(:pdf_generator2122) do
          SwaggerSharedComponents::V0.body_examples[:pdf_generator2122].delete(:organization_name)
        end
        schema '$ref' => '#/components/schemas/Errors'
        run_test!
      end

      response '500', 'Internal server error' do
        schema '$ref' => '#/components/schemas/Errors'
        run_test!
      end
    end
  end
end
