# frozen_string_literal: true
require 'rails_helper'

describe BenchmarkRequest do
  let(:benchmark_request) { described_class.new('evss') }
  let(:redis) { Redis.current }
  let(:benchmark_key) { "benchmark_evss" }

  def average
    BigDecimal.new(redis.get(benchmark_key))
  end

  def count
    redis.get("#{benchmark_key}.count").to_i
  end

  subject do
    benchmark_request.send(:benchmark) do
      123
    end
  end

  before do
    time = Time.utc(2000)
    num_calls = 0

    expect(Time).to receive(:current).twice do
      num_calls += 1
      time + num_calls.seconds
    end
  end

  context 'with an existing average' do
    before do
      redis.set(benchmark_key, BigDecimal.new('0.5'))
      redis.set("#{benchmark_key}.count", 1)
    end

    it 'should set the average and count correctly' do
      subject

      expect(average).to eq(0.75)
      expect(count).to eq(2)
    end
  end

  context 'without an existing average' do
    it 'should set the average and count correctly' do
      subject

      expect(average).to eq(1)
      expect(count).to eq(1)
    end
  end

  it 'should return the blocks return value' do
    expect(subject).to eq(123)
  end

  it 'should log the values to sentry' do
    expect(benchmark_request).to receive(:log_message_to_sentry).with(
      'Average evss request in seconds',
      :info,
      { average: BigDecimal.new(1), count: 1 },
      backend_service: 'evss'
    )

    subject
  end
end
