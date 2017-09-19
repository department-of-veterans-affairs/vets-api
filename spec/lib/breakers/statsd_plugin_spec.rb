# frozen_string_literal: true
require 'rails_helper'

describe Breakers::StatsdPlugin do
  let(:request) { Faraday::Env.new }
  let(:test_host) { 'https://test-host.gov' }

  describe 'get_tags' do
    context 'request is made with no id' do
      it 'returns endpoint tag' do
        request.url = URI(test_host + '/foo')
        expect(subject.get_tags(request)).to include('endpoint:/foo')
      end
    end

    context 'request is made with id' do
      it 'returns endpoint tag with id replaced' do
        request.url = URI(test_host + '/v1/foo/12345')
        expect(subject.get_tags(request)).to include('endpoint:/v1/foo/xxx')

        request.url = URI(test_host + '/page/1/foo/12345')
        expect(subject.get_tags(request)).to include('endpoint:/page/xxx/foo/xxx')
      end
    end
  end
end
