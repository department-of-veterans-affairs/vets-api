# frozen_string_literal: true

require 'rails_helper'

describe Staccato do
  it 'uses the google analytics url in settings' do
    VCR.use_cassette('staccato/event', match_requests_on: %i[method uri]) do
      Staccato.tracker('foo').event(
        category: 'foo'
      )
    end
  end
end
