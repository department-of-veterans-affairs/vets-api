# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/mule_soft_client'

module CARMA
  module Client
    describe MuleSoftClient do
      let(:client) { described_class.new }

      describe '#raise_error_unless_success' do
        context 'with a 202 status code' do
          it 'returns nil' do
            expect(
              client.send(:raise_error_unless_success, '', 202)
            ).to eq(nil)
          end
        end
      end

      describe 'submitting 10-10CG' do
        let(:config) { double('config') }
        let(:exp_headers) { { client_id: '1234', client_secret: 'abcd' } }
        let(:exp_opts) { { timeout: 10 } }
        let(:payload) { '{}' }
        let(:body) { '{}' }
        let(:response) { double('response') }

        before do
          allow(client).to receive(:config).and_return(config)
          allow(config).to receive(:base_request_headers).and_return(exp_headers)
          allow(config).to receive(:timeout).and_return(10)
          allow(config).to receive(:settings).and_return(OpenStruct.new(async_timeout: 60))
        end

        describe '#create_submission_v2' do
          context 'with a records error' do
            it 'raises RecordParseError' do
              expect(client).to receive(:do_post).with('v2/application/1010CG/submit', {}, 60).and_return(
                { 'data' => { 'carmacase' => { 'createdAt' => '2022-08-04 16:44:37', 'id' => 'aB93S0000000FTqSAM' } },
                  'record' => { 'hasErrors' => true,
                                'results' => [{ 'referenceId' => '1010CG', 'id' => '0683S000000YBIFQA4',
                                                'errors' => [] }] } }
              )

              expect do
                client.create_submission_v2({})
              end.to raise_error(CARMA::Client::MuleSoftClient::RecordParseError)
            end
          end
        end

        describe 'form data' do
          context 'successfully' do
            before do
              expect(response).to receive(:status).and_return(200)
              allow(response).to receive(:body).and_return(body)
            end

            it 'POSTs to the correct resource' do
              expect(client).to receive(:perform).with(
                :post,
                'v1/application/1010CG/submit', payload, exp_headers, exp_opts
              ).and_return(response)

              expect { client.create_submission(payload) }.not_to raise_error
            end

            it 'increments statsd' do
              expect(client).to receive(:perform).and_return(response)

              expect do
                client.create_submission(payload)
              end.to trigger_statsd_increment('api.carma.mulesoft.create_submission.total')
            end
          end

          context 'gets an error from the remote' do
            before do
              expect(response).to receive(:status).and_return(400)
              allow(response).to receive(:body).and_return('error')
            end

            it 'raises an error' do
              expect(client).to receive(:perform).with(:post, 'v1/application/1010CG/submit', payload, exp_headers,
                                                       exp_opts)
                                                 .and_return(response)

              expect(Raven).to receive(:extra_context).with(response_body: 'error')

              expect { client.create_submission(payload) }.to raise_error(Common::Exceptions::SchemaValidationErrors)
            end
          end
        end

        describe 'attachments' do
          before do
            expect(response).to receive(:status).and_return(201)
            allow(response).to receive(:body).and_return(body)
          end

          let(:exp_opts) { { timeout: 60 } }

          it 'POSTs to the correct resource' do
            expect(client).to receive(:perform).with(:post, 'v1/application/1010CG/addDocument', payload, exp_headers,
                                                     exp_opts)
                                               .and_return(response)
            expect { client.upload_attachments(payload) }.not_to raise_error
          end

          it 'increments statsd' do
            expect(client).to receive(:perform).and_return(response)

            expect do
              client.upload_attachments(payload)
            end.to trigger_statsd_increment('api.carma.mulesoft.upload_attachments.total')
          end
        end
      end
    end
  end
end
