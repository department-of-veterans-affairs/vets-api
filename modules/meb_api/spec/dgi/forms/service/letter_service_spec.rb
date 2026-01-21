# frozen_string_literal: true

require 'rails_helper'
require 'dgi/forms/service/letter_service'

RSpec.describe MebApi::DGI::Forms::Letters::Service do
  let(:service) { described_class.new(nil) }

  before do
    allow(MebApi::AuthenticationTokenService).to receive(:call).and_return('token123')
  end

  describe '#end_point' do
    it 'constructs path with claimant id and type' do
      endpoint = service.send(:end_point, 600_000_001, 'toe')
      expect(endpoint).to eq('claimant/600000001/claimType/toe/letter')
    end
  end

  describe '#request_headers' do
    it 'builds headers with bearer token' do
      expect(service.send(:request_headers)[:Authorization]).to eq('Bearer token123')
    end
  end

  describe '#get_claim_letter' do
    it 'delegates to perform with correct parameters' do
      expect(service).to receive(:perform).with(
        :get,
        'claimant/1/claimType/fry/letter',
        {},
        service.send(:request_headers),
        hash_including(timeout: 60)
      ).and_return(double('response'))

      service.get_claim_letter(1, 'fry')
    end
  end
end
