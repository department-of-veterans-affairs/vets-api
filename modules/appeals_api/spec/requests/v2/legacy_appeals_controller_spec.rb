# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::V2::DecisionReviews::LegacyAppealsController, type: :request do
  describe '#index' do
    context 'when only ssn provided' do
      it 'GETs legacy appeals from Caseflow successfully' do
        VCR.use_cassette('caseflow/legacy_appeals_get_by_ssn') do
          get_legacy_appeals(ssn: '502628285', file_number: nil)
          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['data']).not_to be nil
          expect(json['data'][0]['attributes']).to include 'latestSocSsocDate'
        end
      end

      context 'when Veteran has no legacy appeals' do
        it 'returns an empty array' do
          VCR.use_cassette('caseflow/veteran_no_legacy_appeals') do
            get_legacy_appeals(ssn: '978257509', file_number: nil)
            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)
            expect(json['data'].length).to be 0
          end
        end
      end

      context 'when ssn formatted incorrectly' do
        it 'returns a 422 error with details' do
          VCR.use_cassette('caseflow/legacy_appeals_get_by_ssn') do
            get_legacy_appeals(ssn: '24-2921hw', file_number: nil)
            errors = JSON.parse(response.body)['errors'][0]
            expect(response).to have_http_status :unprocessable_entity
            expect(errors['detail']).to include 'X-VA-SSN has an invalid format'
          end
        end
      end

      context 'when veteran record does not exist' do
        let(:no_record_ssn) { '234840293' }

        it 'returns a 404' do
          VCR.use_cassette('caseflow/legacy_appeals_no_veteran_record') do
            get_legacy_appeals(ssn: no_record_ssn, file_number: nil)
            errors = JSON.parse(response.body)['errors'][0]
            expect(response).to have_http_status :not_found
            expect(errors['title']).to eq 'Veteran Not Found'
          end
        end
      end
    end

    context 'when only file_number provided' do
      it 'GETs legacy appeals from Caseflow successfully' do
        VCR.use_cassette('caseflow/legacy_appeals_get_by_file_number') do
          get_legacy_appeals(ssn: nil, file_number: '328723195')
          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['data']).not_to be nil
          expect(json['data'][0]['attributes']).to include 'latestSocSsocDate'
        end
      end

      context 'when veteran record does not exist' do
        let(:no_record_file_number) { '010101010' }

        it 'returns a 404' do
          VCR.use_cassette('caseflow/legacy_appeals_no_veteran_record_from_file_number') do
            get_legacy_appeals(ssn: nil, file_number: no_record_file_number)
            errors = JSON.parse(response.body)['errors'][0]
            expect(response).to have_http_status :not_found
            expect(errors['title']).to eq 'Veteran Not Found'
          end
        end
      end
    end

    context 'when X-VA-SSN and X-VA-File-Number are missing' do
      it 'returns a 422' do
        get_legacy_appeals(ssn: nil, file_number: nil)
        expect(response).to have_http_status :unprocessable_entity
        json = JSON.parse(response.body)
        expect(json['errors']).to be_an Array
      end
    end

    context 'when receive and unusable response from Caseflow' do
      before do
        allow_any_instance_of(Caseflow::Service)
          .to(receive(:get_legacy_appeals).and_return(Struct.new(:status, :body).new(200, '<nope nope nope>')))
      end

      it 'returns a 502' do
        get_legacy_appeals(ssn: '123445223', file_number: '222222222')
        expect(response).to have_http_status :bad_gateway
      end
    end

    context 'when receive a Caseflow 4XX response' do
      let(:status) { 400 }
      let(:body) { { this_is: 'great' }.as_json }

      before do
        allow_any_instance_of(Caseflow::Service)
          .to(receive(:get_legacy_appeals).and_return(Struct.new(:status, :body).new(status, body)))
      end

      it 'lets 4XX responses passthrough' do
        get_legacy_appeals(ssn: '123445223', file_number: '222222222')
        expect(response.status).to be status
        expect(JSON.parse(response.body)).to eq body
      end
    end
  end

  private

  def get_legacy_appeals(ssn: nil, file_number: nil)
    headers = {}

    if file_number.present?
      headers['X-VA-File-Number'] = file_number
    elsif ssn.present?
      headers['X-VA-SSN'] = ssn
    end

    get('/services/appeals/v2/decision_reviews/legacy_appeals/', headers: headers)
  end
end
