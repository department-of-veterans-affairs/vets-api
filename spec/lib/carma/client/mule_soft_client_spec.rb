# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/mule_soft_client'

describe CARMA::Client::MuleSoftClient do
  let(:client) { described_class.new }

  before do
    allow(Rails.logger).to receive(:info)
  end

  describe '#create_submission_v2' do
    subject { client.create_submission_v2(payload) }

    let(:config) { double('config') }
    let(:exp_headers) { { client_id: '1234', client_secret: 'abcd' } }
    let(:timeout) { 60 }

    let(:resource) { 'v2/application/1010CG/submit' }
    let(:payload) { {} }

    let(:mulesoft_auth_token_client) { instance_double(CARMA::Client::MuleSoftAuthTokenClient) }

    before do
      allow(client).to receive(:config).and_return(config)
      allow(config).to receive_messages(base_request_headers: exp_headers, timeout: 10)
      allow(CARMA::Client::MuleSoftAuthTokenClient).to receive(:new).and_return(mulesoft_auth_token_client)
    end

    context 'successfully gets token' do
      let(:bearer_token) { 'my-bearer-token' }
      let(:headers) do
        {
          'Authorization' => "Bearer #{bearer_token}",
          'Content-Type' => 'application/json'
        }
      end

      let(:has_errors) { false }
      let(:results) { {} }

      let(:response_body) do
        {
          data: {
            carmacase: {
              createdAt: '2022-08-04 16:44:37',
              id: 'aB93S0000000FTqSAM'
            }
          },
          record: {
            hasErrors: has_errors,
            results:
          }
        }.to_json
      end

      let(:status) { 201 }
      let(:mock_response) { double('FaradayResponse', status:, body: response_body) }

      before do
        allow(mulesoft_auth_token_client).to receive(:new_bearer_token).and_return(bearer_token)
        allow(client).to receive(:perform)
          .with(:post, resource, payload.to_json, headers)
          .and_return(mock_response)
      end

      context 'successful response' do
        [200, 201, 202].each do |status_code|
          context "with a #{status_code} status code" do
            let(:status) { status_code }

            it 'logs submission and response code' do
              expect(Rails.logger).to receive(:info).with(
                "[Form 10-10CG] Submitting to '#{resource}' using bearer token"
              )
              expect(Rails.logger).to receive(:info)
                .with("[Form 10-10CG] Submission to '#{resource}' resource resulted in response code #{status}")
              expect(Sentry).to receive(:set_extras).with(response_body: mock_response.body)

              subject
            end
          end
        end
      end

      context 'non 200 response' do
        let(:status) { 500 }

        it 'raises SchemaValidationError' do
          expect(Rails.logger).to receive(:info)
            .with("[Form 10-10CG] Submitting to '#{resource}' using bearer token")
          expect(Rails.logger).to receive(:info)
            .with("[Form 10-10CG] Submission to '#{resource}' resource resulted in response code 500")
          expect(Rails.logger).to receive(:error).with(
            '[Form 10-10CG] Submission expected 200 status but received 500'
          )

          expect { subject }.to raise_error(Common::Exceptions::SchemaValidationErrors)
        end
      end

      context 'hasErrors is true' do
        let(:has_errors) { true }

        context 'hasErrors in response is true' do
          context 'results is empty' do
            it 'logs carma response' do
              expect(Rails.logger).to receive(:error)
                .with('[Form 10-10CG] response contained attachment errors',
                      {
                        created_at: '2022-08-04 16:44:37',
                        id: 'aB93S0000000FTqSAM',
                        attachments: []
                      })
              expect { subject }.to raise_error(CARMA::Client::MuleSoftClient::RecordParseError)
            end
          end

          context 'results has attachment data' do
            let(:errors) do
              [
                {
                  duplicateResult: nil,
                  message: 'Document Type: bad value for restricted picklist field: invalid',
                  fields: [
                    'CARMA_Document_Type__c'
                  ],
                  statusCode: 'INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST'
                }
              ]
            end
            let(:results) do
              [
                {
                  referenceId: '1010CG',
                  title: '10-10CG_Jane Doe_Doe_06-25-2025',
                  id: nil,
                  errors:
                }
              ]
            end

            it 'logs carma response' do
              expect(Rails.logger).to receive(:error)
                .with('[Form 10-10CG] response contained attachment errors',
                      {
                        created_at: '2022-08-04 16:44:37',
                        id: 'aB93S0000000FTqSAM',
                        attachments: [{
                          reference_id: '1010CG',
                          id: '',
                          errors: [
                            {
                              'duplicateResult' => nil,
                              'message' => 'Document Type: bad value for restricted picklist field: invalid',
                              'fields' => ['CARMA_Document_Type__c'],
                              'statusCode' => 'INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST'
                            }
                          ]
                        }]
                      })
              expect { subject }.to raise_error(CARMA::Client::MuleSoftClient::RecordParseError)
            end
          end
        end
      end
    end

    context 'error getting token' do
      it 'logs error' do
        expect(mulesoft_auth_token_client).to receive(:new_bearer_token)
          .and_raise(CARMA::Client::MuleSoftAuthTokenClient::GetAuthTokenError)

        expect do
          subject
        end.to raise_error(CARMA::Client::MuleSoftAuthTokenClient::GetAuthTokenError)
      end
    end
  end
end
