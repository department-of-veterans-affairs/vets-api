require 'rails_helper'

describe Staccato do
  it 'should use the google analytics url in settings' do
    VCR.use_cassette('staccato/event', match_requests_on: %i[method uri]) do
      Staccato.tracker('foo').event(
        category: 'foo'
      )
    end
  end
end
