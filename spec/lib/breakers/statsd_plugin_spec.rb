# frozen_string_literal: true

require 'rails_helper'

describe Breakers::StatsdPlugin do
  let(:request) { Faraday::Env.new }
  let(:test_host) { 'https://test-host.gov' }

  describe 'get_tags' do
    context 'request is sent' do
      it 'adds method tag when available' do
        request.method = :get
        expect(subject.get_tags(request)).to include('method:get')
      end

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

        request.url = URI(test_host + '/foo/25D05EEE-187A-4332-86BF-BED70E10B6B7')
        expect(subject.get_tags(request)).to include('endpoint:/foo/xxx')

        request.url = URI(test_host + '/foo/25d05eee-187a-4332-86bf-bed70e10b6b7/test')
        expect(subject.get_tags(request)).to include('endpoint:/foo/xxx/test')

        request.url = URI(test_host + '/foo/25d05eee187a433286bfbed70e10b6b7/')
        expect(subject.get_tags(request)).to include('endpoint:/foo/xxx/')

        request.url = URI(test_host + '/foo/111A2222')
        expect(subject.get_tags(request)).to include('endpoint:/foo/xxx')

        request.url = URI(test_host + '/foo/aaaaaaaa/11A22222')
        expect(subject.get_tags(request)).to include('endpoint:/foo/aaaaaaaa/xxx')

        request.url = URI(test_host + '/foo/-1')
        expect(subject.get_tags(request)).to include('endpoint:/foo/xxx')
      end
    end
  end
end
