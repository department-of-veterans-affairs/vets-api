# frozen_string_literal: true

require 'rails_helper'
require 'virtual_regional_office/client'

RSpec.describe VirtualRegionalOffice::Client do
  let(:client) { VirtualRegionalOffice::Client.new }
  let(:params) do
    {
      diagnostic_code: 1234,
      claim_id: 4567,
      form526_submission_id: 789
    }
  end

  describe 'making requests' do
    subject { client.classify_contention_by_diagnostic_code(params) }

    context 'valid requests' do
      describe 'when requesting classification' do
        let(:generic_response) do
          double(
            'virtual regional office response', status: 200,
                                                body: {
                                                  classification_code: '99999', classification_name: 'namey'
                                                }.as_json
          )
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
