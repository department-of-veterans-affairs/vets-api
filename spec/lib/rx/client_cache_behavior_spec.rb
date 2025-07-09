# frozen_string_literal: true

require 'rails_helper'
require 'rx/client'
require 'vets/collection'
require 'rx/configuration'

describe Rx::Client, type: :model do
  let(:session) { { user_id: 'test-user' } }
  let(:client) { described_class.new(session: session) }
  let(:prescription_details) { build(:prescription_details) }
  let(:prescription_details_array) { [prescription_details] }

  before do
    allow(client).to receive(:perform).and_return(double(body: { data: prescription_details_array, metadata: {}, errors: nil }))
    allow(StatsD).to receive(:increment)
  end

  context 'when caching is enabled' do
    before do
      allow(client).to receive(:cache_key).and_return('test-user:medications')
      allow(PrescriptionDetails).to receive(:get_cached).and_return(prescription_details_array)
      allow(PrescriptionDetails).to receive(:set_cached)
    end

    it 'reads from cache if cache_key is present' do
      expect(PrescriptionDetails).to receive(:get_cached).with('test-user:medications')
      client.get_all_rxs
    end

    it 'writes to cache if cache_key is present and data is not cached' do
      allow(PrescriptionDetails).to receive(:get_cached).and_return(nil)
      expect(PrescriptionDetails).to receive(:set_cached).with('test-user:medications', prescription_details_array)
      client.get_all_rxs
    end
  end

  context 'when caching is disabled (cache_key is nil)' do
    before do
      allow(client).to receive(:cache_key).and_return(nil)
      allow(PrescriptionDetails).to receive(:get_cached)
      allow(PrescriptionDetails).to receive(:set_cached)
    end

    it 'does not read from cache if cache_key is nil' do
      expect(PrescriptionDetails).not_to receive(:get_cached)
      client.get_all_rxs
    end

    it 'does not write to cache if cache_key is nil' do
      expect(PrescriptionDetails).not_to receive(:set_cached)
      client.get_all_rxs
    end
  end

  context 'post_refill_rxs and post_refill_rx' do
    before do
      allow(client).to receive(:perform).and_return(true)
      allow(PrescriptionDetails).to receive(:clear_cache)
      allow(Vets::Collection).to receive(:bust)
      allow(client).to receive(:increment_refill)
    end

    it 'clears and busts cache if cache_key is present' do
      allow(client).to receive(:cache_key).with('medications').and_return('test-user:medications')
      allow(client).to receive(:cache_key).with('getactiverx').and_return('test-user:getactiverx')
      expect(PrescriptionDetails).to receive(:clear_cache).with('test-user:medications')
      expect(PrescriptionDetails).to receive(:clear_cache).with('test-user:getactiverx')
      expect(Vets::Collection).to receive(:bust).with(['test-user:medications', 'test-user:getactiverx'])
      client.post_refill_rxs([1,2])
    end

    it 'does not clear or bust cache if cache_key is nil' do
      allow(client).to receive(:cache_key).and_return(nil)
      expect(PrescriptionDetails).not_to receive(:clear_cache)
      expect(Vets::Collection).not_to receive(:bust)
      client.post_refill_rxs([1,2])
    end
  end
end
