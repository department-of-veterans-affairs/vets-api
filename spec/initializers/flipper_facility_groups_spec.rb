# frozen_string_literal: true

require 'rails_helper'
require 'zlib'

RSpec.describe 'Flipper facility percentage groups' do
  let(:station_id) { '358' }
  let(:percentage) { 50 }
  let(:group_name) { :"facility_#{station_id}_#{percentage}pct" }
  let(:feature_name) { :test_facility_feature }

  # Build a user-like actor
  let(:actor) do
    instance_double(
      User,
      flipper_id:,
      vha_facility_ids: facility_ids
    )
  end
  let(:flipper_id) { 'test-user@va.gov' }
  let(:facility_ids) { [station_id] }

  before do
    # Guard against duplicate registration if to_prepare already ran
    unless Flipper.group_exists?(group_name)
      Flipper.register(group_name) do |a, _context|
        next false unless a.respond_to?(:flipper_id) && a.respond_to?(:vha_facility_ids)

        facility_match = a.vha_facility_ids.include?(station_id)
        within_pct = Zlib.crc32("#{station_id}:#{a.flipper_id}") % 100 < percentage
        facility_match && within_pct
      end
    end

    Flipper.add(feature_name) unless Flipper.exist?(feature_name)
    Flipper.enable_group(feature_name, group_name)
  end

  after do
    Flipper.disable(feature_name)
    Flipper.remove(feature_name) if Flipper.exist?(feature_name)
    Flipper.unregister_groups
  end

  context 'when user is at the target facility and within the percentage' do
    # Zlib.crc32('358:user-0@va.gov') % 100 => 18, which is < 50
    let(:flipper_id) { 'user-0@va.gov' }

    it 'enables the feature' do
      expect(Flipper.enabled?(feature_name, actor)).to be true
    end
  end

  context 'when user is at the target facility but outside the percentage' do
    # Zlib.crc32('358:user-3@va.gov') % 100 => 53, which is >= 50
    let(:flipper_id) { 'user-3@va.gov' }

    it 'does not enable the feature' do
      expect(Flipper.enabled?(feature_name, actor)).to be false
    end
  end

  context 'when user is NOT at the target facility' do
    let(:facility_ids) { ['999'] }

    it 'does not enable the feature' do
      expect(Flipper.enabled?(feature_name, actor)).to be false
    end
  end

  context 'when actor does not respond to vha_facility_ids' do
    let(:actor) { instance_double(User, flipper_id: 'test@va.gov') }

    before do
      allow(actor).to receive(:respond_to?).and_return(false)
      allow(actor).to receive(:respond_to?).with(:flipper_id).and_return(true)
    end

    it 'does not enable the feature' do
      expect(Flipper.enabled?(feature_name, actor)).to be false
    end
  end

  describe 'determinism' do
    it 'returns the same result for the same flipper_id every time' do
      results = 10.times.map { Flipper.enabled?(feature_name, actor) }
      expect(results.uniq.size).to eq(1)
    end
  end

  describe 'distribution' do
    let(:facility_ids) { [station_id] }

    it 'enables approximately the configured percentage of actors' do
      total = 1000
      enabled_count = (0...total).count do |i|
        a = instance_double(
          User,
          flipper_id: "user-#{i}@va.gov",
          vha_facility_ids: facility_ids
        )
        Flipper.enabled?(feature_name, a)
      end

      actual_percentage = (enabled_count.to_f / total * 100).round
      # Allow +/- 8% tolerance for statistical variance
      expect(actual_percentage).to be_within(8).of(percentage)
    end
  end
end
