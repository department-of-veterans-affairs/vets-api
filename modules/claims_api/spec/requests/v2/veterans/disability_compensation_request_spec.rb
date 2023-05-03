# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability Claims', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-04-3735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:scopes) { %w[claim.write claim.read] }
  let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', '526.json').read }

  before do
    stub_poa_verification
    stub_mpi
    Timecop.freeze(Time.zone.now)
  end

  after do
    Timecop.return
  end

  describe '#526' do
    context 'submit' do
      let(:claim_date) { (Time.zone.today - 1.day).to_s }
      let(:data) do
        temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                               'form_526_json_api.json').read
        temp = JSON.parse(temp)
        temp['data']['attributes']['claimDate'] = claim_date

        temp.to_json
      end
      let(:veteran_id) { '1012667145V762142' }
      let(:path) { "/services/claims/v2/veterans/#{veteran_id}/526" }
      let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', '526.json').read }
      let(:parsed_codes) do
        {
          birls_id: '111985523',
          participant_id: '32397028'
        }
      end
      let(:add_response) { build(:add_person_response, parsed_codes:) }

      before do
        Timecop.freeze(Time.parse('2022-05-01 12:00:00 UTC'))
      end

      after do
        Timecop.return
      end

      describe "'claim_date'" do
        context 'when it is the appropriate time range' do
          context "and 'claim_date' is the current day" do
            let(:claim_date) { Time.zone.today.to_s }

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('evss/reference_data/countries') do
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context "and 'claim_date' is in the past" do
            let(:claim_date) { (Time.zone.today - 1.day).to_s }

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('evss/reference_data/countries') do
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end
        end

        context 'when it is formatted' do
          context "and 'claim_date' improperly formatted (hello world)" do
            let(:claim_date) { 'hello world' }

            it 'responds with bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end

          context "and 'claim_date' improperly formatted (empty string)" do
            let(:claim_date) { '' }

            it 'responds with bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end
      end
    end

    context 'validate' do
    end

    context 'attachments' do
    end
  end
end
