# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/mule_soft_client'

class MockFaradayResponse
  attr_reader :body, :status

  def initialize(body, status = 200)
    @body = body
    @status = status
  end
end

describe CARMA::Client::MuleSoftClient do
  let(:client) { described_class.new }

  before do
    allow(Rails.logger).to receive(:info)
  end

  describe 'submitting 10-10CG' do
    let(:config) { double('config') }
    let(:exp_headers) { { client_id: '1234', client_secret: 'abcd' } }
    let(:timeout) { 60 }
    let(:v2) do
      OpenStruct.new(
        token_url: 'my/token/url',
        client_id: 'id',
        client_secret: 'secret'
      )
    end

    before do
      allow(client).to receive(:config).and_return(config)
      allow(config).to receive_messages(base_request_headers: exp_headers, timeout: 10,
                                        settings: OpenStruct.new(
                                          async_timeout: timeout,
                                          v2:
                                        ))
    end

    describe '#create_submission_v2' do
      subject { client.create_submission_v2(payload) }

      let(:resource) { 'v2/application/1010CG/submit' }
      let(:has_errors) { false }
      let(:response_body) do
        {
          data: {
            carmacase: {
              createdAt: '2022-08-04 16:44:37',
              id: 'aB93S0000000FTqSAM'
            }
          },
          record: {
            hasErrors: has_errors
          }
        }.to_json
      end
      let(:mock_success_response) { MockFaradayResponse.new(response_body, 201) }
      let(:payload) { {} }

      context 'OAuth 2.0 flipper enabled' do
        let(:mulesoft_token_client) { instance_double(CARMA::Client::MuleSoftTokenClient) }

        before do
          Flipper.enable(:cg_OAuth_2_enabled)
          allow(CARMA::Client::MuleSoftTokenClient).to receive(:new).and_return(mulesoft_token_client)
        end

        after do
          Flipper.disable(:cg_OAuth_2_enabled)
        end

        context 'successfully gets token' do
          let(:bearer_token) { 'my-bearer-token' }

          before do
            allow(mulesoft_token_client).to receive(:new_bearer_token).and_return(bearer_token)
          end

          it 'calls perform with expected params' do
            expect(client).to receive(:perform)
              .with(:post, resource, payload.to_json, { Authorization: "Bearer #{bearer_token}" })
              .and_return(mock_success_response)

            expect(Rails.logger).to receive(:info).with("[Form 10-10CG] Submitting to '#{resource}' using bearer token")
            expect(Rails.logger).to receive(:info)
              .with("[Form 10-10CG] Submission to '#{resource}' resource resulted in response code 201")
            expect(Sentry).to receive(:set_extras).with(response_body: mock_success_response.body)

            subject
          end

          context 'with errors' do
            let(:has_errors) { true }
            let(:mock_error_response) { MockFaradayResponse.new(response_body, 500) }

            it 'raises SchemaValidationError' do
              expect(client).to receive(:perform)
                .with(:post, resource, payload.to_json, { Authorization: "Bearer #{bearer_token}" })
                .and_return(mock_error_response)

              expect(Rails.logger).to receive(:info)
                .with("[Form 10-10CG] Submitting to '#{resource}' using bearer token")
              expect(Rails.logger).to receive(:info)
                .with("[Form 10-10CG] Submission to '#{resource}' resource resulted in response code 500")
              expect(Sentry).to receive(:set_extras).with(response_body: mock_success_response.body)

              expect { subject }.to raise_error(Common::Exceptions::SchemaValidationErrors)
            end
          end
        end

        context 'error getting token' do
          it 'logs error' do
            expect(mulesoft_token_client).to receive(:new_bearer_token)
              .and_raise(CARMA::Client::MuleSoftTokenClient::GetAuthTokenError)

            expect do
              subject
            end.to raise_error(CARMA::Client::MuleSoftTokenClient::GetAuthTokenError)
          end
        end
      end

      context 'OAuth 2.0 flipper disabled' do
        let(:response_body) do
          {
            data: {
              carmacase: {
                createdAt: '2022-08-04 16:44:37',
                id: 'aB93S0000000FTqSAM'
              }
            },
            record: {
              hasErrors: false
            }
          }.to_json
        end
        let(:mock_success_response) { MockFaradayResponse.new(response_body, 201) }

        before do
          Flipper.disable(:cg_OAuth_2_enabled)
        end

        it 'calls perform with expected params' do
          expect(client).to receive(:perform)
            .with(:post, resource, payload.to_json, exp_headers, { timeout: })
            .and_return(mock_success_response)

          expect(Rails.logger).to receive(:info).with("[Form 10-10CG] Submitting to '#{resource}'")
          expect(Rails.logger).to receive(:info)
            .with("[Form 10-10CG] Submission to '#{resource}' resource resulted in response code 201")
          expect(Sentry).to receive(:set_extras).with(response_body: mock_success_response.body)

          subject
        end

        context 'with a records error' do
          it 'raises RecordParseError' do
            expect(client).to receive(:do_post).with(resource, {}, 60).and_return(
              { 'data' => { 'carmacase' => { 'createdAt' => '2022-08-04 16:44:37', 'id' => 'aB93S0000000FTqSAM' } },
                'record' => { 'hasErrors' => true,
                              'results' => [{ 'referenceId' => '1010CG', 'id' => '0683S000000YBIFQA4',
                                              'errors' => [] }] } }
            )
            expect do
              subject
            end.to raise_error(CARMA::Client::MuleSoftClient::RecordParseError)
          end
        end
      end
    end
  end

  describe '#raise_error_unless_success' do
    [200, 201, 202].each do |status_code|
      context "with a #{status_code} status code" do
        subject { client.send(:raise_error_unless_success, 'my/url', status_code) }

        it 'returns nil' do
          expect(subject).to eq(nil)
        end

        it 'logs submission and response code' do
          expect(Rails.logger).to receive(:info)
            .with("[Form 10-10CG] Submission to 'my/url' resource resulted in response code #{status_code}")
          subject
        end
      end
    end
  end
end
