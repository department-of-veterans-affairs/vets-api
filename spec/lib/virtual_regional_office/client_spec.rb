# frozen_string_literal: true

require 'rails_helper'
require 'virtual_regional_office/client'

RSpec.describe VirtualRegionalOffice::Client do
  before(:all) do
    @client = VirtualRegionalOffice::Client.new({
                                                  veteran_icn: '9000682',
                                                  diagnostic_code: '7101',
                                                  claim_submission_id: '1234'
                                                })
  end

  context 'initialization' do
    describe 'when the caller passes a valid icn' do
      it 'initializes the client with the icn set' do
        expect(@client.instance_variable_get(:@veteran_icn)).to eq '9000682'
      end
    end

    describe 'when the caller passes no icn' do
      it 'raises an ArgumentError to the caller' do
        expect do
          VirtualRegionalOffice::Client.new({
                                              diagnostic_code: '7101',
                                              claim_submission_id: '1234'
                                            })
        end.to raise_error(ArgumentError, 'no veteran_icn passed in for request.')
      end
    end

    describe 'when the caller passes a blank icn' do
      it 'raises an ArgumentError to the caller' do
        expect do
          VirtualRegionalOffice::Client.new({
                                              veteran_icn: '',
                                              diagnostic_code: '7101',
                                              claim_submission_id: '1234'
                                            })
        end.to raise_error(ArgumentError, 'no veteran_icn passed in for request.')
      end
    end
  end

  describe 'making requests' do
    context 'valid requests' do
      describe 'when requesting health-data-assessment' do
        let(:generic_response) do
          double('virtual regional office response', status: 200, body: { veteranIcn: '9000682' }.as_json)
        end

        before do
          allow(@client).to receive(:perform).and_return generic_response
        end

        it 'returns the api response' do
          expect(@client.assess_claim).to eq generic_response
        end
      end
    end

    context 'unsuccessful requests' do
      let(:error_state) do
        double('virtual regional office response', status: 404, body: { message: 'No evidence found.' }.as_json)
      end

      before do
        allow(@client).to receive(:perform).and_return error_state
      end

      it 'handles an error' do
        expect(@client.assess_claim).to eq error_state
      end
    end
  end
end
