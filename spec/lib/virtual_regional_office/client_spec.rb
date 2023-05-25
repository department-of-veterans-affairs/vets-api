# frozen_string_literal: true

require 'rails_helper'
require 'virtual_regional_office/client'

RSpec.describe VirtualRegionalOffice::Client do
  let(:client) { VirtualRegionalOffice::Client.new }

  describe 'making requests' do
    subject { client.assess_claim(diagnostic_code: 1234, claim_submission_id: 1, veteran_icn: '9000682') }

    context 'valid requests' do
      describe 'when requesting health-data-assessment' do
        let(:generic_response) do
          double('virtual regional office response', status: 200, body: { veteranIcn: '9000682' }.as_json)
        end

        before do
          allow(client).to receive(:perform).and_return generic_response
        end

        it 'returns the api response' do
          expect(subject).to eq generic_response
        end
      end
    end

    context 'unsuccessful requests' do
      let(:error_state) do
        double('virtual regional office response', status: 404, body: { message: 'No evidence found.' }.as_json)
      end

      before do
        allow(client).to receive(:perform).and_return error_state
      end

      it 'handles an error' do
        expect(subject).to eq error_state
      end
    end
  end
end
