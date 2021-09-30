# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::Service do
  subject { described_class }

  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:opts) do
    {
      data: {
        uuid: id,
        last4: '1234',
        last_name: 'Johnson'
      }
    }
  end
  let(:valid_check_in) { CheckIn::V2::Session.build(opts) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build(check_in: valid_check_in)).to be_an_instance_of(V2::Lorota::Service)
    end
  end

  describe '#token_with_permissions' do
    it 'returns data from lorota' do
      allow_any_instance_of(V2::Lorota::Session).to receive(:from_lorota).and_return('abc123')

      hsh = {
        permission_data: {
          permissions: 'read.full',
          uuid: id,
          status: 'success'
        },
        jwt: 'abc123'
      }

      expect(subject.build(check_in: valid_check_in).token_with_permissions).to eq(hsh)
    end
  end

  describe '#base_path' do
    it 'returns base_path' do
      expect(subject.build(check_in: valid_check_in).base_path).to eq('dev')
    end
  end
end
