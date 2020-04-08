# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SAMLRequestTracker, type: :model do

  describe '#save' do
    it 'sets created_at when missing' do
      tracker = SAMLRequestTracker.create(uuid: 1, payload: {})
      expect(tracker.created_at).not_to be_nil
    end

    it 'leaves created_at untouched when already set' do
      tracker = SAMLRequestTracker.create(uuid: 1, payload: {}, created_at: 10)
      expect(tracker.created_at).to eq(10)
    end
  end

  describe '#safe_payload_attr' do
    it 'nil when not found' do
      expect(SAMLRequestTracker.safe_payload_attr(1, :x)).to be_nil
    end

    it 'nil when attribute is missing' do
      SAMLRequestTracker.create(uuid: 1, payload: {})
      expect(SAMLRequestTracker.safe_payload_attr(1, :x)).to be_nil
    end

    it 'safely finds payload attribute' do
      SAMLRequestTracker.create(uuid: 1, payload: {x: 'ok'})
      expect(SAMLRequestTracker.safe_payload_attr(1, :x)).to eq('ok')
    end
  end

  describe '#age' do
    it 'nil when not found' do
      expect(SAMLRequestTracker.age(1)).to be_nil
    end

    it 'correct age when found' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      SAMLRequestTracker.create(uuid: 1, payload: {})
      Timecop.freeze(Time.zone.parse('2020-01-01T08:03:00Z'))
      expect(SAMLRequestTracker.age(1)).to eq(180)
    end
  end
end
