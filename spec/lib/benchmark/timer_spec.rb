# frozen_string_literal: true

require 'rails_helper'

describe Benchmark::Timer do
  let(:redis) { Redis.current }

  before do
    redis.del('benchmark_test_foo')
    redis.del('benchmark_test_bar')
  end

  it 'stores current time in Redis' do
    Benchmark::Timer.start('test', 'foo')

    expect(redis.get('benchmark_test_foo')).not_to be_nil
    expect(redis.ttl('benchmark_test_foo').positive?).to be true
  end

  context 'timer has started' do
    before do
      redis.set('benchmark_test_foo', Time.now.to_f - 60)
    end

    it 'sends elapsed time to StatsD' do
      expect(StatsD).to receive(:measure).once

      Benchmark::Timer.stop('test', 'foo')

      expect(redis.get('benchmark_test_foo')).to be_nil
    end
  end

  context 'no existing timer' do
    it 'does not log elapsed time to StatsD' do
      msg = 'Could not find benchmark start for test_bar'
      expect(Rails.logger).to receive(:warn).once.with(msg)
      expect(StatsD).not_to receive(:measure)

      Benchmark::Timer.stop('test', 'bar')
    end
  end
end
