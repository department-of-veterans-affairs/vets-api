# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/mule_soft_client'

module CARMA
  module Client
    describe MuleSoftClient do
      let(:client) { described_class.new }

      describe 'submitting 10-10CG' do
        let(:config) { double('config') }
        let(:exp_headers) { { client_id: '1234', client_secret: 'abcd' } }
        let(:exp_opts) { { timeout: 10 } }
        let(:payload) { '{}' }
        let(:body) { '{}' }
        let(:response) { double('response') }

        before do
          allow(client).to receive(:with_monitoring).and_yield
          allow(client).to receive(:config).and_return(config)
          allow(config).to receive(:base_request_headers).and_return(exp_headers)
          allow(config).to receive(:timeout).and_return(10)
        end

        describe 'form data' do
          context 'succesfully' do
            before do
              expect(response).to receive(:status).and_return(200)
            end

            it 'POSTs to the correct resource' do
              expect(response).to receive(:body).and_return(body)
              expect(client).to receive(:perform).with(:post, 'submit', payload, exp_headers, exp_opts)
                                                 .and_return(response)
              expect { client.create_submission(payload) }.not_to raise_error
            end
          end

          context 'gets an error from the remote' do
            before do
              expect(response).to receive(:status).and_return(400)
            end

            it 'raises an error' do
              expect(client).to receive(:perform).with(:post, 'submit', payload, exp_headers, exp_opts)
                                                 .and_return(response)
              expect { client.create_submission(payload) }.to raise_error(Common::Exceptions::SchemaValidationErrors)
            end
          end
        end

        describe 'attachments' do
          before do
            expect(response).to receive(:status).and_return(200)
            expect(response).to receive(:body).and_return(body)
          end

          it 'POSTs to the correct resource' do
            expect(client).to receive(:perform).with(:post, 'addDocument', payload, exp_headers, exp_opts)
                                               .and_return(response)
            expect { client.upload_attachments(payload) }.not_to raise_error
          end
        end
      end
    end
  end
end
