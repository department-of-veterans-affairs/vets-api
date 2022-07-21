# frozen_string_literal: true

require 'rails_helper'
require 'mail_automation/client'

RSpec.describe MailAutomation::Client do
  # setting the client only once for this test set, as it mimics how it's used

  before(:all) do
    @client = MailAutomation::Client.new({
                                           claim_id: 1234,
                                           file_number: 1234,
                                           form526: {
                                             form526: {
                                               disabilities: [{
                                                 name: 'sleep apnea',
                                                 diagnosticCode: 6847
                                               }]
                                             }
                                           },
                                           form526_uploads: []
                                         })
  end

  describe 'making requests' do
    let(:bearer_token_object) { double('bearer response', body: { 'access_token' => 'blah' }) }

    context 'valid requests' do
      let(:generic_response) do
        double('mail automation response', status: 200, body: { packetId: '12345' }.as_json)
      end

      before do
        allow(@client).to receive(:perform).and_return generic_response
        allow(@client).to receive(:authenticate).and_return bearer_token_object
      end

      it 'sets the headers to include the bearer token' do
        response = @client.initiate_apcas_processing
        expect(response.body['packetId']).to eq '12345'
      end
    end

    context 'unsuccessful requests' do
    end
  end
end
