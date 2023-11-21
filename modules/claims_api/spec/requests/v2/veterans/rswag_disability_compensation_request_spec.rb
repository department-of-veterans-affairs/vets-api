# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../rails_helper'
require_relative '../../../support/swagger_shared_components/v2'

describe 'DisabilityCompensation', production: false, swagger_doc: Rswag::TextHelpers.new.claims_api_docs,
                                   vcr: 'claims_api/disability_comp' do
  let(:scopes) { %w[system/claim.read system/claim.write] }

  path '/veterans/{veteranId}/526' do
    post 'Submits form 526' do
      tags 'Disability'
      operationId 'post526Claim'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'

      get_schema_description = <<~VERBIAGE
        Automatically establishes a disability compensation claim (21-526EZ) in Veterans Benefits Management System (VBMS).#{' '}
        This endpoint generates a filled and electronically signed 526EZ form, establishes the disability claim in VBMS, and#{' '}
        submits the form to the Veteran's eFolder.

        A 202 response indicates the API submission was accepted. The claim has not reached VBMS until it has a CLAIM_RECEIVED status.#{' '}
        Check claim status using the GET veterans/{veteranId}/claims/{id} endpoint.

        **A substantially complete 526EZ claim must include:**
        * Veteran's name
        * Sufficient service information for VA to verify the claimed service
        * At least one claimed disability or medical condition and how it relates to service
        * Veteran and/or Representative signature

        **Standard and fully developed claims (FDCs)**

        [Fully developed claims (FDCs)](https://www.va.gov/disability/how-to-file-claim/evidence-needed/fully-developed-claims/)
        are claims certified by the submitter to include all information needed for processing. These claims process faster#{' '}
        than claims submitted through the standard claim process. If a claim is certified for the FDC, but is missing needed information,#{' '}
        it will be processed as a standard claim.

        To certify a claim for the FDC process, set the claimProcessType to FDC_PROGRAM.
      VERBIAGE
      description get_schema_description
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }

      let(:scopes) { %w[system/claim.read system/claim.write] }

      parameter SwaggerSharedComponents::V2.body_examples[:disability_compensation]

      describe 'Getting a successful response' do
        response '202', 'Successful response with disability' do
          schema SwaggerSharedComponents::V2.schemas[:disability_compensation]
          let(:claim_date) { (Time.zone.today - 1.day).to_s }
          let(:anticipated_separation_date) { 2.days.from_now.strftime('%Y-%m-%d') }
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'disability_compensation', 'form_526_json_api.json').read
            temp = JSON.parse(temp)
            attributes = temp['data']['attributes']
            attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] =
              anticipated_separation_date
            temp['data']['attributes'] = attributes
            temp.to_json
            temp
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 202 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting an unauthorized reponse' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'disability_compensation', 'form_526_json_api.json').read
            temp = JSON.parse(temp)
            temp
          end

          before do |example|
            # skip ccg authorization to fail authorization
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting an unprocessable entity response' do
        response '422', 'Unprocessable entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api',
                                            'errors', 'default_with_source.json').read)
          # Build the dropdown for examples
          def append_example_metadata(example, response)
            example.metadata[:response][:content] = {
              'application/json' => {
                examples: {
                  example.metadata[:example_group][:description] => {
                    value: JSON.parse(response.body, symbolize_names: true)
                  }
                }
              }
            }
          end

          def make_request(example)
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          context 'Violates JSON Schema' do
            let(:data) { { data: { attributes: nil } } }

            before do |example|
              make_request(example)
            end

            after do |example|
              append_example_metadata(example, response)
            end

            it 'returns a 422 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end

          context 'Not a JSON Object' do
            let(:data) do
              'This is not valid JSON'
            end

            before do |example|
              make_request(example)
            end

            after do |example|
              append_example_metadata(example, response)
            end

            it 'returns a 422 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/526/validate' do
    post 'Validates a 526 claim form submission.' do
      tags 'Disability'
      operationId 'post526ClaimValidate'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      validate_description = <<~VERBIAGE
        Validates a request for a disability compensation claim submission (21-526EZ).
        This endpoint can be used to test the request parameters for your /526 submission.
      VERBIAGE
      description validate_description

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      parameter SwaggerSharedComponents::V2.body_examples[:disability_compensation]

      describe 'Getting a successful response' do
        response '200', 'Successful response with disability' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'forms',
                                            'disability', 'validate.json').read)
          let(:anticipated_separation_date) { 2.days.from_now.strftime('%Y-%m-%d') }
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'disability_compensation', 'form_526_json_api.json').read
            temp = JSON.parse(temp)
            attributes = temp['data']['attributes']
            attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] =
              anticipated_separation_date
            temp['data']['attributes'] = attributes
            temp.to_json
            temp
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'disability_compensation', 'form_526_json_api.json').read
            temp = JSON.parse(temp)

            temp
          end
          let(:Authorization) { nil }

          before do |example|
            mock_acg(scopes) do
              allow(ClaimsApi::ValidatedToken).to receive(:new).and_return(nil)
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'errors',
                                            'default_with_source.json').read)
          let(:data) { { data: { attributes: nil } } }

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/526/{id}/attachments' do
    post 'Upload documents supporting a 526 claim' do
      tags 'Disability'
      operationId 'upload526Attachments'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'multipart/form-data'
      produces 'application/json'
      put_description = <<~VERBIAGE
        Uploads supporting documents related to a disability compensation claim. This endpoint accepts a document binary PDF as part of a multi-part payload.
      VERBIAGE
      description put_description

      parameter name: :id, in: :path, required: true, type: :string,
                description: 'UUID given when Disability Claim was submitted'

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }

      attachment_description = <<~VERBIAGE
        Attachment contents. Must be provided in binary PDF or [base64 string](https://raw.githubusercontent.com/department-of-veterans-affairs/vets-api/master/modules/claims_api/spec/fixtures/base64pdf) format and less than 11 in x 11 in.
      VERBIAGE
      parameter name: :attachment1,
                in: :formData,
                schema: {
                  type: :object,
                  properties: {
                    attachment1: {
                      type: :file,
                      description: attachment_description
                    },
                    attachment2: {
                      type: :file,
                      description: attachment_description
                    }
                  }
                }

      describe 'Getting an accepted response' do
        response '202', 'upload response' do
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'disability_compensation', 'form_526_json_api.json').read
            temp = JSON.parse(temp)

            temp
          end

          let(:scopes) { %w[system/claim.write] }
          let(:auto_claim) { create(:auto_established_claim) }
          let(:attachment1) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                    .to_s)
          end
          let(:attachment2) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                    .to_s)
          end
          let(:id) { auto_claim.id }

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 202 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'disability_compensation', 'form_526_json_api.json').read
            temp = JSON.parse(temp)

            temp
          end

          let(:scopes) { %w[system/claim.write] }
          let(:auto_claim) { create(:auto_established_claim) }
          let(:attachment1) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                    .to_s)
          end
          let(:attachment2) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                    .to_s)
          end
          let(:id) { auto_claim.id }
          let(:Authorization) { nil }

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'default.json').read)

          let(:scopes) { %w[claim.write] }
          let(:attachment1) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                    .to_s)
          end
          let(:attachment2) do
            Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/'))
                                                    .to_s)
          end
          let(:id) { 999_999_999 }

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/526/generatePDF' do
    post 'Returns filled out 526EZ form as PDF' do
      tags 'Disability'
      operationId 'post526Pdf'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of Veteran'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      let(:data) do
        temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                               'disability_compensation', 'form_526_json_api.json').read
        temp = JSON.parse(temp)

        temp
      end
      parameter SwaggerSharedComponents::V2.body_examples[:disability_compensation]
      pdf_description = <<~VERBIAGE
        Returns a filled out 526EZ form for a disability compensation claim (21-526EZ).

        This endpoint can be used to generate the PDF based on the request data in the case that the submission was not able to be successfully auto-established. The PDF can then be uploaded via the [Benefits Intake API](https://developer.va.gov/explore/api/benefits-intake) to digitally submit directly to the Veterans Benefits Administration's (VBA) claims intake process.
      VERBIAGE
      description pdf_description

      describe 'Getting a successful response' do
        response '200', 'post pdf response' do
          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          let(:Authorization) { nil }

          before do |example|
            mock_acg(scopes) do
              allow(ClaimsApi::ValidatedToken).to receive(:new).and_return(nil)
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end
end
