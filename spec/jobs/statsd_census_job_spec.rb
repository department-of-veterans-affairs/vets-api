# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StatsdCensusJob do
  xit 'should be run on a schedule' do
    # probably start at 30m
    # this will be frequent enough to catch any asg events
  end

  xit 'should create a redis key if it doesn\'t exist already' do
    expect(redis_key_name).to eq 'stat:initialized'
  end

  xit 'should increment all known StatsD keys' do
    expect(a_known_set_of_keys).to have_been_incremented
  end

  xit 'should update the redis set when a new key is used' do
    expect(redis_set).to contain(the_dynamically_generated_key)
  end

  xit 'should set each known StatsD key to incremented' do
    expect(watcher_statsd_key).to have_been_incremented
  end

  xit 'should use a consistent naming format for the redis keys' do
    expect(any_key).to match_the_format
  end

  xit 'handles multiple clients without causing race conditions' do
  end
end
