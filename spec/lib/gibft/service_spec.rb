# frozen_string_literal: true

require 'rails_helper'

describe Gibft::Service, type: :model do
  let(:service) { described_class.new }
  let(:client) { double }

  describe '#submit' do
    before do
      expect(service).to receive(:get_oauth_token).and_return('token')

      expect(Restforce).to receive(:new).with(
        oauth_token: 'token',
        instance_url: Gibft::Configuration::SALESFORCE_INSTANCE_URL,
        api_version: '41.0'
      ).and_return(client)
      expect(client).to receive(:post).with(
        '/services/apexrest/educationcomplaint', {}
      ).and_return(
        OpenStruct.new(
          body: {
            'case_id' => 'case_id',
            'case_number' => 'case_number'
          }
        )
      )
    end

    it 'submits the form' do
      expect(service.submit({})).to eq('case_id' => 'case_id', 'case_number' => 'case_number')
    end
  end
end
