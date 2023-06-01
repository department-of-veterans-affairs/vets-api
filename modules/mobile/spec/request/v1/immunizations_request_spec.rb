# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/helpers/iam_session_helper'
require_relative '../../support/matchers/json_schema_matcher'

RSpec.describe 'immunizations', type: :request do
  include JsonSchemaMatchers

  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before do
    allow(File).to receive(:read).and_return(rsa_key.to_s)
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('9000682')
    iam_sign_in(build(:iam_user))
    Timecop.freeze(Time.zone.parse('2021-10-20T15:59:16Z'))
  end

  after { Timecop.return }

  describe 'GET /mobile/v1/health/immunizations' do
    context 'when the expected fields have data' do
      before do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 1 } }
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the expected schema' do
        # TODO: this should use the matcher helper instead (was throwing an Oj::ParseError)
        # expect().to match_json_schema('immunizations')
        expected_response = {
          'data' => [{
            'id' => 'I2-2BCP5BAI6N7NQSAPSVIJ6INQ4A000000',
            'type' => 'immunization',
            'attributes' => {
              'cvxCode' => 207,
              'date' => '2021-01-14T09:30:21Z',
              'doseNumber' => nil,
              'doseSeries' => nil,
              'groupName' => 'COVID-19',
              'manufacturer' => nil,
              'note' => 'Dose #2 of 2 of COVID-19, mRNA, LNP-S, PF, 100 mcg/ 0.5 mL dose vaccine administered.',
              'reaction' => nil,
              'shortDescription' => 'COVID-19, mRNA, LNP-S, PF, 100 mcg or 50 mcg dose'
            },
            'relationships' => {
              'location' => {
                'data' => { 'id' => 'I2-3JYDMXC6RXTU4H25KRVXATSEJQ000000', 'type' => 'location' },
                'links' => {
                  'related' => 'www.example.com/mobile/v0/health/locations/I2-3JYDMXC6RXTU4H25KRVXATSEJQ000000'
                }
              }
            }
          }],
          'meta' => { 'pagination' =>
                        { 'currentPage' => 1, 'perPage' => 1, 'totalPages' => 15, 'totalEntries' => 15 } }
        }

        expect(response.parsed_body).to eq(expected_response)
      end

      context 'for items that do not have locations' do
        it 'has a blank relationship' do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 1, number: 15 } }
          end

          expect(response.parsed_body['data'][0]['relationships']).to eq(
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
        it 'has a relationship' do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 1, number: 13 } }
          end

          expect(response.parsed_body['data'][0]['relationships']).to eq(
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

    context 'when entry is missing' do
      before do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations_no_entry', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: iam_headers, params: nil
        end
      end

      it 'returns empty array' do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['data']).to eq([])
      end
    end

    context 'when the note is null or an empty array' do
      before do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations_blank_note', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 15, number: 1 } }
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
      let(:immunizations_request_non_covid_paginated) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 1, number: 13 } }
        end
      end
      let(:immunizations_request_covid_paginated) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 1, number: 2 } }
        end
      end
      let(:immunizations_request_covid_no_manufacturer_paginated) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 1, number: 1 } }
        end
      end
      let(:immunizations_request_non_covid_with_manufacturer_paginated) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 1, number: 6 } }
        end
      end

      context 'when an immunization group name is COVID-19 and there is a manufacturer provided' do
        it 'uses the vaccine manufacturer in the response' do
          immunizations_request_covid_paginated
          expect(response.parsed_body['data'][0]['attributes']).to eq(
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
          immunizations_request_covid_no_manufacturer_paginated
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
            immunizations_request_covid_paginated
          end.to trigger_statsd_increment('mobile.immunizations.covid_manufacturer_missing', times: 1)
        end
      end

      context 'when an immunization group name is not COVID-19 and there is a manufacturer provided' do
        it 'sets manufacturer to nil' do
          immunizations_request_non_covid_with_manufacturer_paginated
          expect(response.parsed_body['data'][0]['attributes']).to eq(
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
          immunizations_request_non_covid_paginated

          expect(response.parsed_body['data'][0]['attributes']).to eq(
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
    end

    describe 'pagination' do
      it 'defaults to the first page with ten results per page', :aggregate_failures do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: iam_headers, params: nil
        end

        ids = response.parsed_body['data'].map { |i| i['id'] }
        # these are the last ten records in the vcr cassette
        expected_ids = %w[
          I2-2BCP5BAI6N7NQSAPSVIJ6INQ4A000000
          I2-N7A6Q5AU6W5C6O4O7QEDZ3SJXM000000
          I2-NGT2EAUYD7N7LUFJCFJY3C5KYY000000
          I2-2ZWOY2V6JJQLVARKAO25HI2V2M000000
          I2-JYYSRLCG3BN646ZPICW25IEOFQ000000
          I2-7PQYOMZCN4FG2Z545JOOLAVCBA000000
          I2-GY27FURWILSYXZTY2GQRNJH57U000000
          I2-F3CW7J5IRY6PVIEVDMRL4R4W6M000000
          I2-VLMNAJAIAEAA3TR34PW5VHUFPM000000
          I2-DOUHUYLFJLLPSJLACUDAJF5GF4000000
        ]

        expect(ids).to eq(expected_ids)
      end

      it 'returns the correct page and number of records' do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 2, number: 3 } }
        end

        ids = response.parsed_body['data'].map { |i| i['id'] }

        # these are the fifth and sixth from last records in the vcr cassette
        expect(ids).to eq(%w[I2-JYYSRLCG3BN646ZPICW25IEOFQ000000 I2-7PQYOMZCN4FG2Z545JOOLAVCBA000000])
      end
    end

    describe 'record order' do
      it 'orders records by descending date' do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 15, number: 1 } }
        end

        dates = response.parsed_body['data'].collect { |i| i['attributes']['date'] }

        expect(dates).to eq(%w[
                              2021-01-14T09:30:21Z
                              2020-12-18T12:24:55Z
                              2018-05-10T12:24:55Z
                              2017-05-04T12:24:55Z
                              2016-04-28T12:24:55Z
                              2016-04-28T12:24:55Z
                              2015-04-23T12:24:55Z
                              2015-04-23T12:24:55Z
                              2014-04-17T12:24:55Z
                              2013-04-11T12:24:55Z
                              2012-04-05T12:24:55Z
                              2012-04-05T12:24:55Z
                              2011-03-31T12:24:55Z
                              2010-03-25T12:24:55Z
                              2009-03-19T12:24:55Z
                            ])
      end
    end

    describe 'caching' do
      context 'when data is not cached' do
        it 'calls service' do
          expect_any_instance_of(Mobile::V0::LighthouseHealth::Service).to receive(:get_immunizations)

          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: iam_headers, params: {}
          end
        end

        it 'calls service even when useCache is true' do
          expect_any_instance_of(Mobile::V0::LighthouseHealth::Service).to receive(:get_immunizations)

          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: iam_headers, params: { useCache: true }
          end
        end
      end

      context 'when cache is set' do
        before do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: iam_headers, params: {}
          end
        end

        it 'uses cached data instead of calling service' do
          expect_any_instance_of(Mobile::V0::LighthouseHealth::Service).not_to receive(:get_immunizations)

          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: iam_headers, params: {}
          end
        end

        it 'does not use cache when useCache is false' do
          expect_any_instance_of(Mobile::V0::LighthouseHealth::Service).to receive(:get_immunizations)

          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: iam_headers, params: { useCache: false }
          end
        end
      end
    end

    describe 'when multiple items have same date' do
      context 'date is available' do
        it 'returns items in alphabetical order by group name' do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 10 } }
          end
          expect(response.parsed_body['data'][4]['attributes']).to eq(
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

      context 'date is missing' do
        it 'returns items in alphabetical order by group name with missing date items at end of list' do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations_date_missing',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: iam_headers, params: { page: { size: 4 } }
          end
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
