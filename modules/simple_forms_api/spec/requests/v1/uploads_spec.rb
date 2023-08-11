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

    def self.test_failed_request_scrubs_error_message214142
      it 'makes the request for 21-4142 and expects a failure' do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'form_with_dangerous_characters_21_4142.json')
        data = JSON.parse(fixture_path.read)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:error)
        # 'unexpected token at' gets mangled by our scrubbing but this indicates that we're getting the right message
        expect(response.body).to include('unexpected ken at')
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](0..2))
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](3..4))
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](5..8))
        expect(response.body).not_to include(data.dig('veteran', 'address', 'street'))
        expect(response.body).not_to include(data.dig('veteran', 'address', 'street2'))
        expect(response.body).not_to include(data.dig('veteran', 'address', 'street3'))
      end
    end

    test_failed_request_scrubs_error_message214142

    def self.test_failed_request_scrubs_error_message2110210
      it 'makes the request for 21-10210 and expects a failure' do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'form_with_dangerous_characters_21_10210.json')
        data = JSON.parse(fixture_path.read)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:error)
        # 'unexpected token at' gets mangled by our scrubbing but this indicates that we're getting the right message
        expect(response.body).to include('unexpected token t')
        expect(response.body).not_to include(data['veteran_ssn']&.[](0..2))
        expect(response.body).not_to include(data['veteran_ssn']&.[](3..4))
        expect(response.body).not_to include(data['veteran_ssn']&.[](5..8))
        expect(response.body).not_to include(data['claimant_ssn']&.[](0..2))
        expect(response.body).not_to include(data['claimant_ssn']&.[](3..4))
        expect(response.body).not_to include(data['claimant_ssn']&.[](5..8))
      end
    end

    test_failed_request_scrubs_error_message2110210
  end
end
