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
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
            fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', test_payload)
            data = JSON.parse(fixture_path.read)
            post '/simple_forms_api/v1/simple_forms', params: data
            expect(response).to have_http_status(:ok)
          ensure
            metadata_file = Dir['tmp/*.SimpleFormsApi.metadata.json'][0]
            Common::FileHelpers.delete_file_if_exists(metadata_file) if defined?(metadata_file)
          end
        end
      end
    end

    test_submit_request 'vha_10_10d.json'
    test_submit_request 'vba_26_4555.json'
    test_submit_request 'vba_21_4142.json'
    test_submit_request 'vba_21_10210.json'
    test_submit_request 'vba_21p_0847.json'
    test_submit_request 'vba_21_0972.json'

    def self.test_failed_request_scrubs_error_message(test_payload)
      it 'makes the request and expects a failure' do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', test_payload)
        data = JSON.parse(fixture_path.read)
        post '/simple_forms_api/v1/simple_forms', params: data
        expect(response).to have_http_status(:error)
        expect(response.body).to include('something has gone wrong with your form,')
        expect(response.body).to include(
          'and the entire error message has been redacted to keep PII from getting leaked'
        )
        expect(response.body).not_to include('ssn')
        expect(response.body).not_to include('date_of_birth')
      end
    end

    test_failed_request_scrubs_error_message 'form_with_dangerous_characters.json'
  end
end
