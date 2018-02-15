# frozen_string_literal: true

require 'rails_helper'

shared_examples 'a redis store with a maximum lifetime' do

  before(:each) { subject.save }

  it 'will extend the session only up to the maximum ttl' do
    Timecop.freeze(Time.current)
    subject.created_at = subject.created_at - (described_class.maximum_redis_ttl - 10.seconds)
    expect(subject.expire(3600)).to eq(true)
    expect(subject.ttl).to eq(10)
    Timecop.return
  end

  it 'allows for continuous session extension up to the maximum' do
    start_time = Time.current
    Timecop.freeze(start_time)

    # keep extending session so Redis doesn't kill it while remaining
    # within maximum_redis_ttl
    increment = subject.redis_namespace_ttl - 1.minute
    max_hours = described_class.maximum_redis_ttl / 1.hour
    (1...max_hours).each do |hour|
      Timecop.freeze(start_time + increment * hour)
      expect(subject.expire(described_class.redis_namespace_ttl)).to eq(true)
      expect(subject.ttl).to eq(described_class.redis_namespace_ttl)
    end

    # still within maximum_redis_ttl by 720 seconds
    Timecop.freeze(start_time + increment * max_hours)
    expect(subject.expire(described_class.redis_namespace_ttl)).to eq(true)
    expect(subject.ttl).to eq(720)

    Timecop.return
  end

  context 'when superclass is not RedisStore' do
    let(:some_clazz) do
      class SomeClass
        include Common::MaximumRedisLifetime
      end
    end
    it 'raises exception' do
      expect{ some_clazz }.to raise_exception(ArgumentError)
    end
  end
end