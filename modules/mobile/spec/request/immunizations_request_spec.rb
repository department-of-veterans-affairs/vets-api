# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'immunizations', type: :request do
  include JsonSchemaMatchers

  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  before do
    allow(File).to receive(:read).and_return(rsa_key.to_s)
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('9000682')
    iam_sign_in(build(:iam_user))
    Timecop.freeze(Time.zone.parse('2021-10-20T15:59:16Z'))
  end

  after { Timecop.return }

  describe 'GET /mobile/v0/health/immunizations' do
    context 'when the expected fields have data' do
      before do
        VCR.use_cassette('lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v0/health/immunizations', headers: iam_headers, params: nil
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      context 'for items that do not have locations' do
        it 'matches the expected attributes' do
          expect(response.parsed_body['data'].last['attributes']).to eq(
            {
              'cvxCode' => 140,
              'date' => '2009-03-19T12:24:55Z',
              'doseNumber' => 'Booster',
              'doseSeries' => 1,
              'groupName' => 'FLU',
              'manufacturer' => nil,
              'note' => 'Dose #45 of 101 of Influenza  seasonal  injectable  preservative free vaccine administered.',
              'reaction' => 'Vomiting',
              'shortDescription' => 'Influenza, seasonal, injectable, preservative free'
            }
          )
        end

        it 'has a blank relationship' do
          expect(response.parsed_body['data'].last['relationships']).to eq(
            {
              'location' => {
                'data' => nil,
                'links' => {
                  'related' => nil
                }
              }
            }
          )
        end
      end

      context 'for items that do have a location' do
        it 'matches the expected attributes' do
          expect(response.parsed_body['data'][12]['attributes']).to eq(
            {
              'cvxCode' => 140,
              'date' => '2011-03-31T12:24:55Z',
              'doseNumber' => 'Series 1',
              'doseSeries' => 1,
              'groupName' => 'FLU',
              'manufacturer' => nil,
              'note' => 'Dose #47 of 101 of Influenza  seasonal  injectable  preservative free vaccine administered.',
              'reaction' => 'Other',
              'shortDescription' => 'Influenza, seasonal, injectable, preservative free'
            }
          )
        end

        it 'has a relationship' do
          expect(response.parsed_body['data'][12]['relationships']).to eq(
            {
              'location' => {
                'data' => {
                  'id' => 'I2-4KG3N5YUSPTWD3DAFMLMRL5V5U000000',
                  'type' => 'location'
                },
                'links' => {
                  'related' => 'www.example.com/mobile/v0/health/locations/I2-4KG3N5YUSPTWD3DAFMLMRL5V5U000000'
                }
              }
            }
          )
        end
      end
    end

    context 'when the note is null or an empty array' do
      before do
        VCR.use_cassette('lighthouse_health/get_immunizations_blank_note', match_requests_on: %i[method uri]) do
          get '/mobile/v0/health/immunizations', headers: iam_headers, params: nil
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns nil for blank notes' do
        expect(response.parsed_body['data'][2]['attributes']['note']).to be_nil
      end

      it 'returns nil for null notes' do
        expect(response.parsed_body['data'][1]['attributes']['note']).to be_nil
      end

      it 'returns a value for notes that have a value' do
        expect(response.parsed_body['data'][0]['attributes']['note']).to eq(
          'Dose #47 of 101 of Influenza  seasonal  injectable  preservative free vaccine administered.'
        )
      end
    end

    describe 'vaccine group name and manufacturer population' do
      let(:immunizations_request) do
        VCR.use_cassette('lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v0/health/immunizations', headers: iam_headers, params: nil
        end
      end

      context 'when an immunization group name is COVID-19 and there is a manufacturer provided' do
        it 'uses the vaccine manufacturer in the response' do
          immunizations_request
          expect(response.parsed_body['data'][1]['attributes']).to eq(
            {
              'cvxCode' => 207,
              'date' => '2020-12-18T12:24:55Z',
              'doseNumber' => nil,
              'doseSeries' => nil,
              'groupName' => 'COVID-19',
              'manufacturer' => 'Moderna US, Inc.',
              'note' =>
                'Dose #1 of 2 of COVID-19, mRNA, LNP-S, PF, 100 mcg/ 0.5 mL dose vaccine administered.',
              'reaction' => nil,
              'shortDescription' => 'COVID-19, mRNA, LNP-S, PF, 100 mcg or 50 mcg dose'
            }
          )
        end
      end

      context 'when an immunization group name is COVID-19 and there is no manufacturer provided' do
        it 'sets manufacturer to nil' do
          immunizations_request
          expect(response.parsed_body['data'][0]['attributes']).to eq(
            {
              'cvxCode' => 207,
              'date' => '2021-01-14T09:30:21Z',
              'doseNumber' => nil,
              'doseSeries' => nil,
              'groupName' => 'COVID-19',
              'manufacturer' => nil,
              'note' =>
                'Dose #2 of 2 of COVID-19, mRNA, LNP-S, PF, 100 mcg/ 0.5 mL dose vaccine administered.',
              'reaction' => nil,
              'shortDescription' => 'COVID-19, mRNA, LNP-S, PF, 100 mcg or 50 mcg dose'
            }
          )
        end

        it 'increments statsd' do
          expect do
            immunizations_request
          end.to trigger_statsd_increment('mobile.immunizations.covid_manufacturer_missing', times: 1)
        end
      end

      context 'when an immunization group name is not COVID-19 and there is a manufacturer provided' do
        it 'sets manufacturer to nil' do
          immunizations_request

          expect(response.parsed_body['data'][5]['attributes']).to eq(
            {
              'cvxCode' => 33,
              'date' => '2016-04-28T12:24:55Z',
              'doseNumber' => 'Series 1',
              'doseSeries' => 1,
              'groupName' => 'PneumoPPV',
              'manufacturer' => nil,
              'note' =>
                'Dose #1 of 1 of pneumococcal polysaccharide vaccine  23 valent vaccine administered.',
              'reaction' => 'Other',
              'shortDescription' => 'pneumococcal polysaccharide PPV23'
            }
          )
        end
      end

      context 'when an immunization group name is not COVID-19 and there is no manufacturer provided' do
        it 'sets manufacturer to nil' do
          immunizations_request

          expect(response.parsed_body['data'][12]['attributes']).to eq(
            {
              'cvxCode' => 140,
              'date' => '2011-03-31T12:24:55Z',
              'doseNumber' => 'Series 1',
              'doseSeries' => 1,
              'groupName' => 'FLU',
              'manufacturer' => nil,
              'note' =>
                'Dose #47 of 101 of Influenza  seasonal  injectable  preservative free vaccine administered.',
              'reaction' => 'Other',
              'shortDescription' =>
                'Influenza, seasonal, injectable, preservative free'
            }
          )
        end
      end

      context 'when cvx_code is missing' do
        let(:immunizations_request_missing_cvx) do
          VCR.use_cassette('lighthouse_health/get_immunizations_cvx_code_missing', match_requests_on: %i[method uri]) do
            get '/mobile/v0/health/immunizations', headers: iam_headers, params: nil
          end
        end

        it 'increments statsd' do
          expect do
            immunizations_request_missing_cvx
          end.to trigger_statsd_increment('mobile.immunizations.cvx_code_missing', times: 1)
        end

        it 'returns a 200' do
          immunizations_request_missing_cvx
          expect(response).to have_http_status(:ok)
        end

        it 'sets cvxCode and manufacturer to nil' do
          immunizations_request_missing_cvx
          attributes = response.parsed_body.dig('data', 1, 'attributes')
          expect(attributes['cvxCode']).to be_nil
          expect(attributes['manufacturer']).to be_nil
        end
      end

      context 'when date is missing' do
        let(:immunizations_request_missing_date) do
          VCR.use_cassette('lighthouse_health/get_immunizations_date_missing', match_requests_on: %i[method uri]) do
            get '/mobile/v0/health/immunizations', headers: iam_headers, params: nil
          end
        end

        it 'increments statsd' do
          expect do
            immunizations_request_missing_date
          end.to trigger_statsd_increment('mobile.immunizations.date_missing', times: 1)
        end

        it 'returns a 200' do
          immunizations_request_missing_date
          expect(response).to have_http_status(:ok)
        end

        it 'sets date to nil' do
          immunizations_request_missing_date
          expect(response.parsed_body.dig('data', 3, 'attributes', 'date')).to be_nil
        end

        it 'returns items in alphabetical order by group name with missing date items at end of list' do
          immunizations_request_missing_date
          expect(response.parsed_body['data'][0]['attributes']).to eq(
            {
              'cvxCode' => 140,
              'date' => '2016-04-28T12:24:55Z',
              'doseNumber' => nil,
              'doseSeries' => nil,
              'groupName' => 'FLU',
              'manufacturer' => nil,
              'note' =>
                'Dose #52 of 101 of Influenza  seasonal  injectable  preservative free vaccine administered.',
              'reaction' => 'Anaphylaxis or collapse',
              'shortDescription' => 'Influenza, seasonal, injectable, preservative free'
            }
          )
          expect(response.parsed_body['data'][1]['attributes']).to eq(
            {
              'cvxCode' => 33,
              'date' => '2016-04-28T12:24:55Z',
              'doseNumber' => 'Series 1',
              'doseSeries' => 1,
              'groupName' => 'PneumoPPV',
              'manufacturer' => nil,
              'note' =>
                'Dose #1 of 1 of pneumococcal polysaccharide vaccine  23 valent vaccine administered.',
              'reaction' => 'Other',
              'shortDescription' => 'pneumococcal polysaccharide PPV23'
            }
          )
          expect(response.parsed_body['data'].last['attributes']).to eq(
            {
              'cvxCode' => 140,
              'date' => nil,
              'doseNumber' => 'Booster',
              'doseSeries' => 1,
              'groupName' => 'FLU',
              'manufacturer' => nil,
              'note' => 'Dose #45 of 101 of Influenza  seasonal  injectable  preservative free vaccine administered.',
              'reaction' => 'Vomiting',
              'shortDescription' => 'Influenza, seasonal, injectable, preservative free'
            }
          )
        end
      end
    end
  end
end
