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
      expect(StatsD).to receive(:increment).with(
        metric_name,
        tags: array_including(*default_tags, *custom_tags)
      )

      subject.track_count(metric_name, tags: custom_tags)
    end
  end

  describe '#track_duration' do
    it 'sends duration in milliseconds to StatsD' do
      expected_duration = ((to - from) * 1000).to_i

      expect(StatsD).to receive(:distribution).with(
        metric_name,
        expected_duration,
        tags: array_including(*default_tags, *custom_tags)
      )

      subject.track_duration(metric_name, from:, to:, tags: custom_tags)
    end
  end

  describe '#trace' do
    let(:span_name) { 'test.span' }
    # Use a dotted key to ensure tags with periods work end-to-end.
    let(:initial_span_tags) { { 'initial.tag' => 'initial_value' } }
    let(:dynamic_span_tag) { { dynamic_tag: 'dynamic_value' } }
    let(:mock_span) { instance_double(Datadog::Tracing::Span) }
    let(:mock_trace) { double('Trace', set_tag: true) }

    before do
      allow(Datadog::Tracing).to receive(:trace).and_yield(mock_span)
      allow(mock_span).to receive(:set_error)
      allow(Datadog::Tracing).to receive(:active_trace).and_return(nil)
    end

    it 'calls Datadog::Tracing.trace with the correct span name and service' do
      expect(Datadog::Tracing).to receive(:trace).with(span_name, service: service_name)
      subject.trace(span_name) { 'block_executed' }
    end

    it 'sets initial tags on the span' do
      initial_span_tags.each do |key, value|
        expect(mock_span).to receive(:set_tag).with(key, value)
      end
      subject.trace(span_name, tags: initial_span_tags) { 'block_executed' }
    end

    it 'sets root trace tags when provided' do
      allow(Datadog::Tracing).to receive(:active_trace).and_return(mock_trace)
      root_tags = { 'poa_request.poa_code' => '123', 'org' => 'ABC' }
      root_tags.each do |k, v|
        expect(mock_trace).to receive(:set_tag).with(k, v)
      end
      subject.trace(span_name, root_tags:) { 'block_executed' }
    end

    it 'yields the span to the block' do
      expect do |b|
        subject.trace(span_name, &b)
      end.to yield_with_args(mock_span)
    end

    it 'allows dynamic tags to be set within the block' do
      expect(mock_span).to receive(:set_tag).with(dynamic_span_tag.keys.first, dynamic_span_tag.values.first)
      subject.trace(span_name) do |span|
        span.set_tag(dynamic_span_tag.keys.first, dynamic_span_tag.values.first)
      end
    end

    it 'filters out nil/blank tag values but keeps false/zero' do
      tags = {
        'drop.nil' => nil,
        'drop.blank' => '',
        'keep.zero' => 0,
        'keep.false' => false,
        'keep.str' => 'ok'
      }

      expect(mock_span).to receive(:set_tag).with('keep.zero', 0)
      expect(mock_span).to receive(:set_tag).with('keep.false', false)
      expect(mock_span).to receive(:set_tag).with('keep.str', 'ok')
      # No expectations for nil/blank keys
      subject.trace(span_name, tags:) { 'block_executed' }
    end

    context 'when an exception occurs in the block' do
      let(:error_message) { 'Something went wrong!' }
      let(:test_error) { StandardError.new(error_message) }

      it 'calls set_error on the span' do
        expect(mock_span).to receive(:set_error).with(test_error)

        expect do
          subject.trace(span_name) { raise test_error }
        end.to raise_error(test_error)
      end

      it 're-raises the original exception' do
        expect do
          subject.trace(span_name) { raise test_error }
        end.to raise_error(test_error)
      end
    end
  end

  describe '#merge_tags' do
    it 'combines custom tags with default service tags and removes duplicates' do
      merged_tags = subject.send(:merge_tags, custom_tags)

      expect(merged_tags).to match_array(default_tags + custom_tags + ["service:#{service_name}"])
    end
  end
end
