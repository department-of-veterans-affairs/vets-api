# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require_relative '../../../support/swagger_shared_components/v0'

RSpec.describe 'PDF Generator 21-22', openapi_spec: 'modules/representation_management/app/swagger/v0/swagger.json',
                                      type: :request do
  before do
    create(:accredited_organization,
           id: SwaggerSharedComponents::V0.representative[:organization_id],
           name: 'Veterans Organization')
    create(:accredited_individual,
           id: SwaggerSharedComponents::V0.representative[:id])
  end

  path '/representation_management/v0/pdf_generator2122' do
    post('Generate a PDF for form 21-22') do
      tags 'PDF Generation'
      consumes 'application/json'
      operationId 'createPdfForm2122'

      parameter SwaggerSharedComponents::V0.body_examples[:pdf_generator2122_parameter]

      response '200', 'PDF generated successfully' do
        produces 'application/pdf'
        let(:pdf_generator2122) do
          SwaggerSharedComponents::V0.body_examples[:pdf_generator2122]
        end
        run_test!
      end

      response '422', 'unprocessable entity response' do
        produces 'application/json'
        let(:pdf_generator2122) do
          params = SwaggerSharedComponents::V0.body_examples[:pdf_generator2122]
          params[:veteran][:name].delete(:first)
          params
        end
        schema '$ref' => '#/components/schemas/errors'
        run_test!
      end
    end
  end
end
