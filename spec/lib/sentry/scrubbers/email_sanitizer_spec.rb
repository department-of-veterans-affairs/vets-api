# frozen_string_literal: true

require 'rails_helper'
require 'sentry/scrubbers/email_sanitizer'

RSpec.describe Sentry::Scrubbers::EmailSanitizer do
  let(:bad_string) { 'Email is: joe.schmoe@gmail.com, bad!' }
  let(:good_string) { 'Email is: [FILTERED EMAIL], bad!' }

  before do
    @scrubber = Sentry::Scrubbers::EmailSanitizer.new
  end

  it 'filters out emails from hashes' do
    data = {}
    data['sensitive'] = bad_string

    results = @scrubber.process(data)
    expect(results['sensitive']).to eq(good_string)
  end

  it 'filters emails from exception messages' do
    data = Exception.new(bad_string)

    results = @scrubber.process(data)
    expect(results.message).to eq(good_string)
    expect(results).to be_a(Exception)
  end

  it 'works recursively on hashes' do
    data = { 'nested' => {} }
    data['nested']['sensitive'] = bad_string

    results = @scrubber.process(data)
    expect(results['nested']['sensitive']).to eq(good_string)
  end

  it 'works recursively on arrays' do
    data = ['good string', 'good string',
            ['good string', bad_string]]

    results = @scrubber.process(data)
    expect(results[2][1]).to eq(good_string)
  end

  it 'does not blow up on symbols' do
    data = { key: :value }

    results = @scrubber.process(data)
    expect(results[:key]).to eq(:value)
  end

  it 'does not filter non-email related data' do
    nonsensitive_str = 'This string (.com) does not contain @ any emails! .edu'
    data = {}
    data['nonsensitive'] = nonsensitive_str

    results = @scrubber.process(data)
    expect(results['nonsensitive']).to eq(nonsensitive_str)
  end

  it 'works on hashes that contain arrays' do
    data = {
      this: %w[that this and_uh],
      that: {
        this: ['that_and_uh', 'Dre, creep to the mic, like a phantom@aol.com']
      }
    }

    filtered_data = {
      this: %w[that this and_uh],
      that: {
        this: ['that_and_uh', 'Dre, creep to the mic, like a [FILTERED EMAIL]']
      }
    }

    results = @scrubber.process(data)
    expect(results).to eq(filtered_data)
  end
end
