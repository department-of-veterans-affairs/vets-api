# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SAMLRequestTracker, type: :model do
  describe '#save' do
    it 'sets created_at when missing' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      tracker = SAMLRequestTracker.create(uuid: 1, payload: {})
      expect(tracker.created_at).to eq(1_577_865_600)
    end

    it 'leaves created_at untouched when already set' do
      tracker = SAMLRequestTracker.create(uuid: 1, payload: {}, created_at: 10)
      expect(tracker.created_at).to eq(10)
    end

    it 'sets payload when missing' do
      tracker = SAMLRequestTracker.create(uuid: 1)
      expect(tracker.payload).to eq({})
    end
  end

  describe '#payload_attr' do
    it 'nil when not found' do
      tracker = SAMLRequestTracker.new
      expect(tracker.payload_attr(:x)).to be_nil
    end

    it 'nil when attribute is missing' do
      tracker = SAMLRequestTracker.new(payload: {})
      expect(tracker.payload_attr(:x)).to be_nil
    end

    it 'finds payload attribute' do
      tracker = SAMLRequestTracker.new(payload: { x: 'ok' })
      expect(tracker.payload_attr(:x)).to eq('ok')
    end
  end

  describe '#age' do
    it '0 when not set' do
      tracker = SAMLRequestTracker.new
      expect(tracker.age).to eq(0)
    end

    it 'correct age when set' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      tracker = SAMLRequestTracker.create(uuid: 1, payload: {})
      Timecop.freeze(Time.zone.parse('2020-01-01T08:03:00Z'))
      expect(tracker.age).to eq(180)
    end
  end
end
