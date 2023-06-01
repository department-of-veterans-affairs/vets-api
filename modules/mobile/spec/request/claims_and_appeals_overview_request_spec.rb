# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'
require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/service'

RSpec.shared_examples 'claims and appeals overview' do |lighthouse_flag|
  let(:good_claims_response_vcr_path) do
    lighthouse_flag ? 'mobile/lighthouse_claims/index/200_response' : 'mobile/claims/claims'
  end

  let(:error_claims_response_vcr_path) do
    lighthouse_flag ? 'mobile/lighthouse_claims/index/404_response' : 'mobile/claims/claims_with_errors'
  end

  before do
    if lighthouse_flag
      token = 'abcdefghijklmnop'
      allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
      Flipper.enable(:mobile_lighthouse_claims)
    else
      Flipper.disable(:mobile_lighthouse_claims)
    end
  end

  describe '#index is polled an unauthorized user' do
    it 'and not user returns a 401 status' do
      get '/mobile/v0/claims-and-appeals-overview'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /v0/claims-and-appeals-overview' do
    before { iam_sign_in }

    let(:params) { { useCache: false, page: { size: 60 } } }

    describe '#index (all user claims) is polled' do
      it 'and a result that matches our schema is successfully returned with the 200 status ' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: iam_headers, params:)
            expect(response).to have_http_status(:ok)
            # check a couple entries to make sure the data is correct
            parsed_response_contents = response.parsed_body['data']
            if lighthouse_flag
              expect(parsed_response_contents.length).to eq(11)
              expect(response.parsed_body.dig('meta', 'pagination', 'totalPages')).to eq(1)
              open_claim = parsed_response_contents.select { |entry| entry['id'] == '600383363' }[0]
              closed_claim = parsed_response_contents.select { |entry| entry['id'] == '600229968' }[0]
              decision_letter_sent_claim = parsed_response_contents.select { |entry| entry['id'] == '600323434' }[0]
              nil_dates_claim = parsed_response_contents.last
              expect(open_claim.dig('attributes', 'updatedAt')).to eq('2022-09-30')
              expect(closed_claim.dig('attributes', 'updatedAt')).to eq('2021-03-22')
              expect(nil_dates_claim.dig('attributes', 'updatedAt')).to eq(nil)
              expect(nil_dates_claim.dig('attributes', 'dateFiled')).to eq(nil)
            else
              expect(parsed_response_contents.length).to eq(60)
              expect(response.parsed_body.dig('meta', 'pagination', 'totalPages')).to eq(3)
              open_claim = parsed_response_contents.select { |entry| entry['id'] == '600114693' }[0]
              closed_claim = parsed_response_contents.select { |entry| entry['id'] == '600106271' }[0]
              decision_letter_sent_claim = parsed_response_contents.select { |entry| entry['id'] == '600096536' }[0]
              expect(open_claim.dig('attributes', 'updatedAt')).to eq('2017-09-28')
              expect(closed_claim.dig('attributes', 'updatedAt')).to eq('2017-09-20')
            end

            open_appeal = parsed_response_contents.select { |entry| entry['id'] == '3294289' }[0]
            expect(open_claim.dig('attributes', 'completed')).to eq(false)
            expect(closed_claim.dig('attributes', 'completed')).to eq(true)
            expect(open_appeal.dig('attributes', 'completed')).to eq(false)
            expect(open_claim['type']).to eq('claim')
            expect(closed_claim['type']).to eq('claim')
            expect(open_appeal['type']).to eq('appeal')
            expect(open_appeal.dig('attributes', 'updatedAt')).to eq('2018-01-16')
            expect(open_appeal.dig('attributes', 'displayTitle')).to eq('disability compensation appeal')
            expect(open_claim.dig('attributes', 'decisionLetterSent')).to eq(false)
            expect(closed_claim.dig('attributes', 'decisionLetterSent')).to eq(false)
            expect(open_appeal.dig('attributes', 'decisionLetterSent')).to eq(false)
            expect(decision_letter_sent_claim.dig('attributes', 'decisionLetterSent')).to eq(true)

            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end

      it 'and invalid headers return a 401 status' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get '/mobile/v0/claims-and-appeals-overview'
            expect(response).to have_http_status(:unauthorized)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    describe '#index (all user claims) is polled with additional pagination params' do
      let(:params) do
        { useCache: false,
          startDate: '2017-05-01T07:00:00.000Z',
          page: { number: 2, size: 2 } }
      end

      it 'and the results are for page 2 of a 12 item pages which only has 10 entries' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: iam_headers, params:)
            expect(response).to have_http_status(:ok)

            # check a couple entries to make sure the data is correct
            parsed_response_contents = response.parsed_body['data']
            expect(parsed_response_contents.length).to eq(2)
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end
    end

    describe '#index (all user claims) is polled requesting only closed claims' do
      let(:params) do
        { useCache: false,
          startDate: '2017-05-01T07:00:00.000Z',
          showCompleted: true }
      end

      it 'and the results contain only closed records' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: iam_headers, params:)
            expect(response).to have_http_status(:ok)
            # check a couple entries to make sure the data is correct
            parsed_response_contents = response.parsed_body['data']
            parsed_response_contents.each do |entry|
              expect(entry.dig('attributes', 'completed')).to eq(true)
            end
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end
    end

    describe '#index (all user claims) is polled requesting only open claims' do
      let(:params) do
        { useCache: false,
          startDate: '2017-05-01T07:00:00.000Z',
          showCompleted: false }
      end

      it 'and the results contain only open records' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: iam_headers, params:)
            expect(response).to have_http_status(:ok)
            # check a couple entries to make sure the data is correct
            parsed_response_contents = response.parsed_body['data']
            parsed_response_contents.each do |entry|
              expect(entry.dig('attributes', 'completed')).to eq(false)
            end
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end
    end

    describe '#index is polled' do
      let(:params) { { useCache: false } }

      it 'and claims service fails, but appeals succeeds' do
        VCR.use_cassette(error_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: iam_headers, params:)

            parsed_response_contents = response.parsed_body['data']
            expect(parsed_response_contents[0]['type']).to eq('appeal')
            expect(parsed_response_contents.last['type']).to eq('appeal')
            expect(response).to have_http_status(:multi_status)
            expect(response.parsed_body.dig('meta', 'errors').length).to eq(1)
            expect(response.parsed_body.dig('meta', 'errors')[0]['service']).to eq('claims')
            open_appeal = parsed_response_contents.select { |entry| entry['id'] == '3294289' }[0]
            closed_appeal = parsed_response_contents.select { |entry| entry['id'] == '2348605' }[0]
            expect(open_appeal.dig('attributes', 'completed')).to eq(false)
            expect(closed_appeal.dig('attributes', 'completed')).to eq(true)
            expect(open_appeal['type']).to eq('appeal')
            expect(closed_appeal['type']).to eq('appeal')
            expect(open_appeal.dig('attributes', 'displayTitle')).to eq('disability compensation appeal')
            expect(closed_appeal.dig('attributes', 'displayTitle')).to eq('appeal')
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end

      it 'and appeals service fails, but claims succeeds' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/server_error') do
            get('/mobile/v0/claims-and-appeals-overview', headers: iam_headers, params:)
            expect(response).to have_http_status(:multi_status)
            parsed_response_contents = response.parsed_body['data']
            expect(parsed_response_contents[0]['type']).to eq('claim')
            expect(parsed_response_contents.last['type']).to eq('claim')
            expect(response.parsed_body.dig('meta', 'errors').length).to eq(1)
            expect(response.parsed_body.dig('meta', 'errors')[0]['service']).to eq('appeals')
            if lighthouse_flag
              open_claim = parsed_response_contents.select { |entry| entry['id'] == '600383363' }[0]
              closed_claim = parsed_response_contents.select { |entry| entry['id'] == '600229968' }[0]
            else
              open_claim = parsed_response_contents.select { |entry| entry['id'] == '600114693' }[0]
              closed_claim = parsed_response_contents.select { |entry| entry['id'] == '600106271' }[0]
            end
            expect(open_claim.dig('attributes', 'completed')).to eq(false)
            expect(closed_claim.dig('attributes', 'completed')).to eq(true)
            expect(open_claim['type']).to eq('claim')
            expect(closed_claim['type']).to eq('claim')
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end

      it 'both fail in upstream service' do
        VCR.use_cassette(error_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/server_error') do
            get('/mobile/v0/claims-and-appeals-overview', headers: iam_headers, params:)
            expect(response).to have_http_status(:bad_gateway)
            expect(response.parsed_body.dig('meta', 'errors').length).to eq(2)
            expect(response.parsed_body.dig('meta', 'errors')[0]['service']).to eq('claims')
            expect(response.parsed_body.dig('meta', 'errors')[1]['service']).to eq('appeals')
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end
    end

    context 'when an internal error occurs getting claims' do
      it 'includes appeals but has error details in the meta object for claims' do
        if lighthouse_flag
          allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claims).and_raise(NoMethodError)
        else
          allow_any_instance_of(IAMUser).to receive(:loa).and_raise(NoMethodError)
        end
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: iam_headers, params:)

            expect(response.parsed_body['data'].size).to eq(
              5
            )
            expect(response.parsed_body.dig('meta', 'errors').first).to eq(
              { 'service' => 'claims',
                'errorDetails' => 'NoMethodError' }
            )
          end
        end
      end
    end

    context 'when there are cached claims and appeals' do
      let(:user) { FactoryBot.build(:iam_user) }
      let(:params) { { useCache: true } }

      before do
        iam_sign_in
        path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'claims_and_appeals.json')
        data = Mobile::V0::Adapters::ClaimsOverview.new.parse(JSON.parse(File.read(path)))
        Mobile::V0::ClaimOverview.set_cached(user, data)
      end

      it 'retrieves the cached appointments rather than hitting the service' do
        expect_any_instance_of(Mobile::V0::Claims::Proxy).not_to receive(:get_claims_and_appeals)
        get('/mobile/v0/claims-and-appeals-overview', headers: iam_headers, params:)
        expect(response).to have_http_status(:ok)
        parsed_response_contents = response.parsed_body['data']
        open_claim = parsed_response_contents.select { |entry| entry['id'] == '600114693' }[0]
        expect(open_claim.dig('attributes', 'completed')).to eq(false)
        expect(open_claim['type']).to eq('claim')
        expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
      end
    end
  end
end

RSpec.describe 'claims and appeals overview', type: :request do
  include JsonSchemaMatchers

  it_behaves_like 'claims and appeals overview', false
  it_behaves_like 'claims and appeals overview', true
end
