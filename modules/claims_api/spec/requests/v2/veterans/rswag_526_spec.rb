# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../rails_helper'
require_relative '../../../support/swagger_shared_components/v2'

describe 'DisabilityCompensation', openapi_spec: Rswag::TextHelpers.new.claims_api_docs do
  let(:scopes) { %w[system/claim.read system/claim.write] }
  let(:generate_pdf_minimum_validations_scopes) { %w[system/claim.read system/claim.write system/526-pdf.override] }
  let(:synchronous_scopes) { %w[system/claim.read system/claim.write system/526.override] }
  let(:veteran_mpi_data) { MPIData.new }
  let(:veteran) { ClaimsApi::Veteran.new }

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

  describe '526 submit', skip: 'Disabling tests for deactivated /veterans/{veteranId}/526 endpoint' do
    path '/veterans/{veteranId}/526', vcr: 'claims_api/disability_comp' do
      post 'Asynchronously establishes disability compensation claim' do
        tags 'Disability Compensation Claims'
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

        request_template = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                                      'disability_compensation', 'form_526_json_api.json').read)
        request_template['data']['attributes']['serviceInformation'].delete('federalActivation')
        request_template['data']['attributes']['serviceInformation']['servicePeriods'].each do |per|
          per.delete('separationLocationCode')
        end

        parameter name: :disability_comp_request, in: :body,
                  schema: SwaggerSharedComponents::V2.body_examples[:disability_compensation][:schema]

        parameter in: :body, examples: {
          'Minimum Required Attributes' => {
            value: JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                              'disability_compensation', 'valid_526_minimum.json').read)
          },
          'Maximum Attributes' => {
            value: request_template

          }
        }

        describe 'Getting a successful response' do
          response '202', 'Successful response' do
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

            let(:disability_comp_request) do
              data
            end

            schema SwaggerSharedComponents::V2.schemas[:disability_compensation]

            before do |example|
              mock_ccg(scopes) do
                submit_request(example.metadata)
              end
            end

            it 'returns a valid 202 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end
        end

        describe 'Getting an unauthorized response' do
          response '401', 'Unauthorized' do
            schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                              'disability_compensation', 'default.json').read)

            let(:data) do
              temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                     'disability_compensation', 'form_526_json_api.json').read
              temp = JSON.parse(temp)
              temp
            end

            let(:disability_comp_request) do
              data
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

        describe 'Getting a 404 response' do
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

          let(:disability_comp_request) do
            data
          end

          before do |example|
            expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
            allow(veteran).to receive(:mpi).and_return(nil)
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

          response '404', 'Resource not found' do
            schema JSON.parse(
              Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                              'disability_compensation', 'default_without_source.json').read
            )

            it 'returns a 404 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end
        end

        describe 'Getting an unprocessable entity response' do
          response '422', 'Unprocessable entity' do
            schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                              'disability_compensation', 'default_with_source.json').read)

            def make_request(example)
              mock_ccg(scopes) do
                submit_request(example.metadata)
              end
            end

            context 'Violates JSON Schema' do
              let(:data) { { data: { attributes: nil } } }

              let(:disability_comp_request) do
                data
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

            context 'Not a JSON Object' do
              let(:data) do
                'This is not valid JSON'
              end

              let(:disability_comp_request) do
                data
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
  end

  path '/veterans/{veteranId}/526/synchronous' do
    post 'Submits disability compensation claim synchronously (restricted access)' do
      tags 'Disability Compensation Claims'
      operationId 'post526ClaimSynchronous'
      security [
        { productionOauth: ['system/526.override'] },
        { sandboxOauth: ['system/526.override'] }
      ]
      consumes 'application/json'
      produces 'application/json'

      get_schema_description = <<~VERBIAGE
        Automatically establishes a disability compensation claim (21-526EZ) in Veterans Benefits Management System (VBMS). This endpoint synchronously generates a filled and electronically signed 526EZ form and establishes the disability claim in VBMS. The 526EZ form is uploaded asynchronously.

        A 202 response indicates the API submission was accepted and the claim was established in VBMS. Check claim status using the GET veterans/{veteranId}/claims/{id} endpoint. The claim status details response will return the associated 526EZ PDF in the supportingDocuments list.

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

      let(:scopes) { %w[system/526.override] }

      parameter name: :disability_comp_request, in: :body,
                schema: SwaggerSharedComponents::V2.body_examples[:disability_compensation][:schema]

      merged_values = {}
      merged_values[:meta] = { transactionId: '00000000-0000-0000-0000-000000000000' }
      parsed_json = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                               'disability_compensation', 'form_526_json_api.json').read)
      parsed_json['data']['attributes']['serviceInformation']['federalActivation']['anticipatedSeparationDate'] =
        2.days.from_now.strftime('%Y-%m-%d')
      parsed_json['data']['attributes']['serviceInformation']['servicePeriods'][-1]['activeDutyEndDate'] =
        2.days.from_now.strftime('%Y-%m-%d')
      merged_values[:data] = parsed_json['data']

      request_template = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                                    'disability_compensation', 'form_526_json_api.json').read)
      request_template['data']['attributes']['serviceInformation'].delete('federalActivation')
      request_template['data']['attributes']['serviceInformation']['servicePeriods'].each do |per|
        per.delete('separationLocationCode')
      end
      parameter in: :body, examples: {
        'Minimum Required Attributes' => {
          value: JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                            'disability_compensation', 'valid_526_minimum.json').read)
        },
        'Maximum Attributes' => {
          value: request_template

        },
        'Transaction ID' => {
          value: merged_values
        }
      }

      describe 'Getting a successful response' do
        response '202', 'Successful response' do
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

          schema SwaggerSharedComponents::V2.schemas[:sync_disability_compensation]

          def make_request(example)
            Flipper.disable :claims_load_testing

            with_settings(Settings.claims_api.benefits_documents, use_mocks: true) do
              VCR.use_cassette('claims_api/disability_comp') do
                VCR.use_cassette('claims_api/evss/submit') do
                  mock_ccg_for_fine_grained_scope(synchronous_scopes) do
                    submit_request(example.metadata)
                  end
                end
              end
            end
          end

          context '202 without a transactionId' do
            let(:disability_comp_request) do
              data
            end

            before do |example|
              make_request(example)
            end

            after do |example|
              append_example_metadata(example, response)
            end

            it 'returns a valid 202 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end

          context '202 with a transactionId' do
            let(:disability_comp_request) do
              merged_values
            end

            before do |example|
              make_request(example)
            end

            after do |example|
              append_example_metadata(example, response)
            end

            it 'returns a valid 202 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end
        end
      end

      describe 'Getting an unauthorized response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'disability_compensation', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'disability_compensation', 'form_526_json_api.json').read
            temp = JSON.parse(temp)
            temp
          end

          let(:disability_comp_request) do
            data
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

      describe 'Getting a 404 response' do
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

        let(:disability_comp_request) do
          data
        end

        before do |example|
          expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
          allow(veteran).to receive(:mpi).and_return(nil)
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

        response '404', 'Resource not found' do
          schema JSON.parse(
            Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                            'disability_compensation', 'default_without_source.json').read
          )

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting an unprocessable entity response' do
        response '422', 'Unprocessable entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'disability_compensation', 'default_with_source.json').read)

          def make_request(example)
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          context 'Violates JSON Schema' do
            let(:data) { { data: { attributes: nil } } }

            let(:disability_comp_request) do
              data
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

          context 'Not a JSON Object' do
            let(:data) do
              'This is not valid JSON'
            end

            let(:disability_comp_request) do
              data
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

  path '/veterans/{veteranId}/526/validate', vcr: 'claims_api/disability_comp' do
    post 'Validates a 526 claim form submission.' do
      tags 'Disability Compensation Claims'
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
                                            'disability_compensation', 'default.json').read)

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

      describe 'Getting a 404 response' do
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

        let(:disability_comp_request) do
          data
        end

        before do |example|
          expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
          allow(veteran).to receive(:mpi).and_return(nil)
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

        response '404', 'Resource not found' do
          schema JSON.parse(
            Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                            'disability_compensation', 'default_without_source.json').read
          )

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'disability_compensation', 'default_with_source.json').read)
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

  describe '526 attachments', skip: 'Disabling tests for deactivated /veterans/{veteranId}/526/{id}/attachments' do
    path '/veterans/{veteranId}/526/{id}/attachments', vcr: 'claims_api/disability_comp' do
      post 'Upload documents supporting a 526 claim' do
        tags 'Disability Compensation Claims'
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
            schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2',
                                              'veterans', 'disability_compensation', 'attachments.json').read)

            let(:data) do
              temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                     'disability_compensation', 'form_526_json_api.json').read
              temp = JSON.parse(temp)

              temp
            end

            let(:scopes) { %w[system/claim.write] }
            let(:auto_claim) { create(:auto_established_claim_v2) }
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
                                              'disability_compensation', 'default.json').read)

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
                                              'disability_compensation', 'default_without_source.json').read)

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
  end

  path '/veterans/{veteranId}/526/generatePDF/minimum-validations', vcr: 'claims_api/disability_comp' do
    post 'Returns filled out 526EZ form as PDF with minimum validations (restricted access)' do
      tags 'Disability Compensation Claims'
      operationId 'post526Pdf'
      security [
        { productionOauth: ['system/526-pdf.override'] },
        { sandboxOauth: ['system/526-pdf.override'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/pdf'

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
                               'disability_compensation', 'form_526_generate_pdf_json_api.json').read
        temp = JSON.parse(temp)

        temp
      end
      parameter SwaggerSharedComponents::V2.body_examples[:disability_compensation_generate_pdf]
      pdf_description = <<~VERBIAGE
        Returns a filled out 526EZ form for a disability compensation claim (21-526EZ).

        This endpoint can be used to generate the PDF based on the request data in the case that the submission was not able to be successfully auto-established. The PDF can then be uploaded via the [Benefits Intake API](https://developer.va.gov/explore/api/benefits-intake) to digitally submit directly to the Veterans Benefits Administration's (VBA) claims intake process.
      VERBIAGE
      description pdf_description

      describe 'Getting a successful response' do
        response '200', 'post pdf response' do
          schema type: :string, format: :binary
          before do |example|
            mock_ccg_for_fine_grained_scope(generate_pdf_minimum_validations_scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/pdf' => {
                'example' => 'string'
              }
            }
          end

          let(:example_metadata_response) do
            { code: '200',
              description: 'post pdf response',
              schema: { type: :string, format: :binary } }
          end
          it 'returns a valid 200 response' do |example|
            expect(example_metadata_response).to eq(example.metadata[:response])
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'disability_compensation', 'default.json').read)

          let(:Authorization) { nil }

          before do |example|
            mock_ccg_for_fine_grained_scope(generate_pdf_minimum_validations_scopes) do
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

      describe 'Getting a 404 response' do
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

        let(:disability_comp_request) do
          data
        end

        before do |example|
          expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
          allow(veteran).to receive(:mpi).and_return(nil)
          mock_ccg_for_fine_grained_scope(generate_pdf_minimum_validations_scopes) do
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

        response '404', 'Resource not found' do
          schema JSON.parse(
            Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                            'disability_compensation', 'default_without_source.json').read
          )

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end
end
