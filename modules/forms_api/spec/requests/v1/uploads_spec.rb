# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dynamic forms uploader', type: :request do
  describe 'form request' do
    let(:client_stub) { instance_double(CentralMail::Service) }
    let :multipart_request_matcher do
      lambda do |r1, r2|
        [r1, r2].each { |r| normalized_multipart_request(r) }
        expect(r1.headers).to eq(r2.headers)
      end
    end

    def self.test_submit_request(test_payload)
      it 'makes the request' do
        VCR.use_cassette(
          'central_mail/upload_mainform_only',
          match_requests_on: [multipart_request_matcher, :method, :uri]
        ) do
          fixture_path = Rails.root.join('modules', 'forms_api', 'spec', 'fixtures', 'form_json', test_payload)
          data = JSON.parse(fixture_path.read)
          post '/forms_api/v1/simple_forms', params: data
          expect(response).to have_http_status(:ok)
        end
      end
    end

    test_submit_request 'vha_10_10d.json'
    test_submit_request 'vba_26_4555.json'
  end
end
