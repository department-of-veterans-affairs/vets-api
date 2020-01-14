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

        request.url = URI(test_host + '/foo/0123456789V123456/bar')
        expect(subject.get_tags(request)).to include('endpoint:/foo/xxx/bar')

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

        request.url = URI(test_host + '/v1/foo/0123456789V123456%5ENI%5E200M%5EUSVHA')
        expect(subject.get_tags(request)).to include('endpoint:/v1/foo/xxx')

        request.url = URI(test_host + '/foo/-1')
        expect(subject.get_tags(request)).to include('endpoint:/foo/xxx')

        request.url = URI(test_host + '/v0.0/Providers(1234567890)/bar')
        expect(subject.get_tags(request)).to include('endpoint:/v0.0/xxx/bar')

        request.url = URI(test_host + '/api/v1/users/b3366359af05d661342470')
        expect(subject.get_tags(request)).to include('endpoint:/api/v1/users/xxx')

        request.url = URI(test_host + '/api/v1/users/00u2sgjcthlnuo12o297')
        expect(subject.get_tags(request)).to include('endpoint:/api/v1/users/xxx')

        request.url = URI(test_host + '/api/v1/users/00u2i1p1u8m7l7FYb297/grants')
        expect(subject.get_tags(request)).to include('endpoint:/api/v1/users/xxx/grants')
      end
    end

    context 'request without an id' do
      it 'doesnt replace anything' do
        request.url = URI(test_host + '/foo/bar')
        expect(subject.get_tags(request)).to include('endpoint:/foo/bar')
      end
    end
  end
end
