# frozen_string_literal: true

require 'rails_helper'
require 'common/client/middleware/request/soap_headers'

describe Common::Client::Middleware::Request::SOAPHeaders do
  context 'with a request without headers' do
    let(:env) { instance_double(Faraday::Env) }
    let(:request_headers) { { 'User-Agent' => 'Faraday v0.9.2', 'Soapaction' => 'PRPA_IN201305UV02' } }
    let(:app) { proc { |n| n } }

    it 'adds headers' do
      now = Time.current
      Timecop.freeze(now)
      subject.instance_variable_set('@app', app)
      allow(env).to receive_messages(request_headers:, body: '<xml></xml>')
      subject.call(env)
      expect(env.request_headers).to eq(
        'Content-Length' => '11',
        'Date' => now.utc.strftime('%a, %d %b %Y %H:%M:%S GMT'),
        'Soapaction' => 'PRPA_IN201305UV02',
        'User-Agent' => 'Faraday v0.9.2'
      )
      Timecop.return
    end
  end
end
