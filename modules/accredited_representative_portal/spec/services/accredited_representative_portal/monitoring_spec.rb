# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::Monitoring do
  subject { described_class.new(service_name, default_tags:) }

  let(:service_name) { 'accredited-representative-portal' }
  let(:default_tags) { ['env:test'] }
  let(:metric_name) { 'test.metric' }
  let(:custom_tags) { ['tag1:value1'] }
  let(:from) { Time.current }
  let(:to) { from + 5 } # Simulate a 5-second duration

  describe '#initialize' do
    it 'sets the service name' do
      expect(subject.instance_variable_get(:@service)).to eq(service_name)
    end

    it 'sets the default tags' do
      expect(subject.instance_variable_get(:@default_tags)).to eq(default_tags)
    end
  end

  describe '#track_count' do
    it 'increments the StatsD metric with the correct tags' do
      expect(StatsD).to receive(:increment).with(metric_name, tags: array_including(*default_tags, *custom_tags))

      subject.track_count(metric_name, tags: custom_tags)
    end
  end

  describe '#track_duration' do
    it 'sends duration in milliseconds to StatsD' do
      expected_duration = ((to - from) * 1000).to_i

      expect(StatsD).to receive(:distribution).with(metric_name, expected_duration,
                                                    tags: array_including(*default_tags, *custom_tags))

      subject.track_duration(metric_name, from:, to:, tags: custom_tags)
    end
  end

  describe '#merge_tags' do
    it 'combines custom tags with default service tags and removes duplicates' do
      merged_tags = subject.send(:merge_tags, custom_tags)

      expect(merged_tags).to match_array(default_tags + custom_tags + ["service:#{service_name}"])
    end
  end
end
