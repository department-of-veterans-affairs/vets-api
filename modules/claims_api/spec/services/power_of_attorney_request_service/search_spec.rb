# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'bgs_client_helpers.rb')

metadata = {
  bgs: {
    service: 'manage_representative_service',
    operation: 'read_poa_request'
  }
}

RSpec.describe ClaimsApi::PowerOfAttorneyRequestService::Search, metadata do
  subject { described_class.perform(**params) }

  describe 'with nonexistent poa code' do
    let(:params) do
      {
        poa_codes: ['1'],
        statuses: ['New']
      }
    end

    it 'returns an empty result set' do
      use_bgs_cassette('nonexistent_poa_code') do
        expect(subject).to eq([])
      end
    end
  end
end
