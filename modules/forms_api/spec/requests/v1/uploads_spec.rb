# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dynamic forms uploader', type: :request do
  describe '10-10d' do
    let(:client_stub) { instance_double(CentralMail::Service) }
    let :multipart_request_matcher do
      lambda do |r1, r2|
        [r1, r2].each { |r| normalized_multipart_request(r) }
        expect(r1.headers).to eq(r2.headers)
      end
    end

    it 'makes the request' do
      VCR.use_cassette(
        'central_mail/upload_mainform_only',
        match_requests_on: [multipart_request_matcher, :method, :uri]
      ) do
        fixture_path = Rails.root.join('modules', 'forms_api', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json')
        data = JSON.parse(fixture_path.read)
        post '/forms_api/v1/submit', params: data
        result = JSON.parse(response.body)
        expect(result['status']).to eq('success')
      end
    end
  end
end
