# frozen_string_literal: true

require 'rails_helper'

describe Breakers::StatsdPlugin do
  let(:request) { Faraday::Env.new }
  let(:response) { Faraday::Env.new }
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

        request.url = URI(test_host + '/api/v1/users/b3363659ac50d661149470')
        expect(subject.get_tags(request)).to include('endpoint:/api/v1/users/xxx')

        request.url = URI(test_host + '/api/v1/users/00u2sgjcthlgio12o297')
        expect(subject.get_tags(request)).to include('endpoint:/api/v1/users/xxx')

        request.url = URI(test_host + '/api/v1/users/00u2i1p2u2m3l7FYb712/grants')
        expect(subject.get_tags(request)).to include('endpoint:/api/v1/users/xxx/grants')

        request.url = URI(test_host + '/cce/v1/patients/1012845331V153043/eligibility/Podiatry')
        expect(subject.get_tags(request)).to include('endpoint:/cce/v1/patients/xxx/eligibility/zzz')
      end
    end

    context 'request without an id' do
      it 'doesnt replace anything' do
        request.url = URI(test_host + '/foo/bar')
        expect(subject.get_tags(request)).to include('endpoint:/foo/bar')
      end
    end
  end

  describe 'send_metric' do
    let(:abstract_service) { Common::Client::Base }

    context 'request env is not null' do
      it 'builds metrics with request env' do
        allow_any_instance_of(Breakers::StatsdPlugin).to receive(:get_tags).and_return('request_env')
        allow(response).to receive(:[]).with(:duration).and_return(50)

        expect_any_instance_of(StatsD).to receive('increment').and_return({})
        expect_any_instance_of(StatsD).to receive('measure').and_return({})

        subject.send_metric('ok', abstract_service, request, response)
      end

      it 'builds metrics with request env and does not make StatsD measure call' do
        allow_any_instance_of(Breakers::StatsdPlugin).to receive(:get_tags).and_return('request_env')

        expect_any_instance_of(StatsD).to receive('increment').and_return({})
        expect_any_instance_of(StatsD).not_to receive('measure')

        subject.send_metric('ok', abstract_service, request, response)
      end
    end
  end
end
