# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V2::DecisionReviews::LegacyAppealsController, type: :request do
  let(:headers) { {} }
  let(:ssn) { nil }
  let(:file_number) { nil }
  let(:icn) { nil }

  describe '#index' do
    context 'when only ssn provided' do
      let(:ssn) { '502628285' }

      it 'GETs legacy appeals from Caseflow successfully' do
        VCR.use_cassette('caseflow/legacy_appeals_get_by_ssn') do
          get_legacy_appeals
          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['data']).not_to be nil
          expect(json['data'][0]['attributes']).to include 'latestSocSsocDate'
        end
      end

      context 'when Veteran has no legacy appeals' do
        let(:ssn) { '978257509' }

        it 'returns an empty array' do
          VCR.use_cassette('caseflow/veteran_no_legacy_appeals') do
            get_legacy_appeals
            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)
            expect(json['data'].length).to be 0
          end
        end
      end

      context 'when ssn formatted incorrectly' do
        let(:ssn) { '24-2921hw' }

        it 'returns a 422 error with details' do
          VCR.use_cassette('caseflow/legacy_appeals_get_by_ssn') do
            get_legacy_appeals
            error = JSON.parse(response.body)['errors'][0]
            expect(response).to have_http_status :unprocessable_entity
            expect(error['detail']).to include "'24-2921hw' did not match the defined pattern"
            expect(error['source']['pointer']).to eq '/X-VA-SSN'
          end
        end
      end

      context 'when valid icn provided' do
        let(:ssn) { '502628285' }
        let(:icn) { '1234567890V012345' }

        it 'GETs legacy appeals from Caseflow successfully' do
          VCR.use_cassette('caseflow/legacy_appeals_get_by_ssn') do
            get_legacy_appeals
            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)
            expect(json['data']).not_to be_nil
            expect(json['data'][0]['attributes']).to include('latestSocSsocDate')
          end
        end
      end

      context 'when icn formatted incorrectly' do
        let(:ssn) { '502628285' }
        let(:icn) { '338487' }

        it 'returns a 422 error with details' do
          get_legacy_appeals
          expect(response).to have_http_status(:unprocessable_entity)
          json = JSON.parse(response.body)
          expect(json['errors']).to be_an(Array)
        end
      end

      context 'when veteran record does not exist' do
        let(:ssn) { '234840293' }

        it 'returns a 404' do
          VCR.use_cassette('caseflow/legacy_appeals_no_veteran_record') do
            get_legacy_appeals
            errors = JSON.parse(response.body)['errors'][0]
            expect(response).to have_http_status :not_found
            expect(errors['title']).to eq 'Veteran Not Found'
          end
        end
      end
    end

    context 'when only file_number provided' do
      let(:file_number) { '328723195' }

      it 'GETs legacy appeals from Caseflow successfully' do
        VCR.use_cassette('caseflow/legacy_appeals_get_by_file_number') do
          get_legacy_appeals
          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['data']).not_to be nil
          expect(json['data'][0]['attributes']).to include 'latestSocSsocDate'
        end
      end

      context 'when veteran record does not exist' do
        let(:file_number) { '010101010' }

        it 'returns a 404' do
          VCR.use_cassette('caseflow/legacy_appeals_no_veteran_record_from_file_number') do
            get_legacy_appeals
            errors = JSON.parse(response.body)['errors'][0]
            expect(response).to have_http_status :not_found
            expect(errors['title']).to eq 'Veteran Not Found'
          end
        end
      end
    end

    context 'when X-VA-SSN and X-VA-File-Number are missing' do
      it 'returns a 422' do
        get_legacy_appeals
        expect(response).to have_http_status :unprocessable_entity
        json = JSON.parse(response.body)
        expect(json['errors']).to be_an Array
      end
    end

    context 'when receive and unusable response from Caseflow' do
      let(:ssn) { '123445223' }
      let(:file_number) { '222222222' }

      before do
        allow_any_instance_of(Caseflow::Service)
          .to(receive(:get_legacy_appeals).and_return(Struct.new(:status, :body).new(200, '<nope nope nope>')))
      end

      it 'returns a 502' do
        get_legacy_appeals
        expect(response).to have_http_status :bad_gateway
      end
    end

    context 'when receive a Caseflow 4XX response' do
      let(:status) { 400 }
      let(:body) { { this_is: 'great' }.as_json }
      let(:ssn) { '123445223' }
      let(:file_number) { '222222222' }

      before do
        allow_any_instance_of(Caseflow::Service)
          .to(receive(:get_legacy_appeals).and_return(Struct.new(:status, :body).new(status, body)))
      end

      it 'lets 4XX responses passthrough' do
        get_legacy_appeals
        expect(response.status).to be status
        expect(JSON.parse(response.body)).to eq body
      end
    end

    context 'using the versioned namespace route' do
      let(:ssn) { '502628285' }
      let(:icn) { '1013062086V794840' }
      let(:oauth_path) { '/services/appeals/legacy_appeals/v0/legacy_appeals/' }

      it 'behaves the same as when using the original route' do
        original_response = nil
        VCR.use_cassette('caseflow/legacy_appeals_get_by_ssn') do
          get_legacy_appeals
          expect(response).to have_http_status(:ok)
          original_response = JSON.parse(response.body)
        end
        VCR.use_cassette('caseflow/legacy_appeals_get_by_ssn') do
          with_openid_auth(
            AppealsApi::LegacyAppeals::V0::LegacyAppealsController::OAUTH_SCOPES[:GET]
          ) do |auth_header|
            get_legacy_appeals(oauth_path, auth_header)
          end
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(original_response)
        end
      end

      context 'with oauth' do
        it_behaves_like(
          'an endpoint with OpenID auth',
          AppealsApi::LegacyAppeals::V0::LegacyAppealsController::OAUTH_SCOPES[:GET]
        ) do
          def make_request(auth_header)
            VCR.use_cassette('caseflow/legacy_appeals_get_by_ssn') do
              get_legacy_appeals(oauth_path, auth_header)
            end
          end
        end
      end
    end
  end

  private

  def get_legacy_appeals(path = '/services/appeals/v2/decision_reviews/legacy_appeals/', extra_headers = {})
    headers = extra_headers || {}

    if file_number.present?
      headers['X-VA-File-Number'] = file_number
    elsif ssn.present?
      headers['X-VA-SSN'] = ssn
    end
    headers['X-VA-ICN'] = icn if icn.present?

    get(path, headers: headers)
  end
end
