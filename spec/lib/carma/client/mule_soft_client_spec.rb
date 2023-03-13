# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/mule_soft_client'

describe CARMA::Client::MuleSoftClient do
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
  end
end
