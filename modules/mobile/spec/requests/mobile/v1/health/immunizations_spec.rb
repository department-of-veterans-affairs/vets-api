# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V1::Health::Immunizations', :skip_json_api_validation, type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(icn: '9000682') }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before do
    Timecop.freeze(Time.zone.parse('2021-10-20T15:59:16Z'))
    allow_any_instance_of(Mobile::V0::LighthouseAssertion).to receive(:rsa_key).and_return(
      OpenSSL::PKey::RSA.new(rsa_key.to_s)
    )
  end

  after { Timecop.return }

  describe 'GET /mobile/v1/health/immunizations' do
    context 'when the expected fields have data' do
      before do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1 } }
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('v1/immunizations')
      end

      context 'for items that do not have locations' do
        it 'has a blank relationship' do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 12, number: 1 } }
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
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 11 } }
          end
          expect(response.parsed_body['data'][0]['relationships']).to eq(
            {
              'location' => {
                'data' => {
                  'id' => 'I2-2TKGVAXW355BKTBNRE4BP7N7XE000000',
                  'type' => 'location'
                },
                'links' => {
                  'related' => 'www.example.com/mobile/v0/health/locations/I2-2TKGVAXW355BKTBNRE4BP7N7XE000000'
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
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: nil
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
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 12, number: 1 } }
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

    context 'when token service returns an error' do
      before do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations_token_too_many_error',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 12, number: 1 } }
        end
      end

      it 'returns a 502' do
        expect(response).to have_http_status(:bad_gateway)
        error = { 'errors' => [{ 'title' => 'Bad Gateway',
                                 'detail' => 'Received an an invalid response from the upstream server',
                                 'code' => 'MOBL_502_upstream_error',
                                 'status' => '502' }] }
        expect(response.parsed_body).to eq(error)
      end
    end

    describe 'vaccine group name and manufacturer population' do
      let(:immunizations_request_non_covid_paginated) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 11 } }
        end
      end
      let(:immunizations_request_covid_no_manufacturer_paginated) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 2 } }
        end
      end
      let(:immunizations_request_non_covid_with_manufacturer_paginated) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 6 } }
        end
      end

      context 'when an immunization group name is COVID-19 and there is a manufacturer provided' do
        it 'uses the vaccine manufacturer in the response' do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 14, number: 1 } }
          end
          covid_with_manufacturer_immunization = response.parsed_body['data'].select do |i|
            i['id'] == 'I2-R5T5WZ3D6UNCTRUASZ6N6IIVXM000000'
          end

          expect(covid_with_manufacturer_immunization.dig(0, 'attributes')).to eq(
            { 'cvxCode' => 213,
              'date' => '2021-04-18T09:59:25Z',
              'doseNumber' => 'Series 1',
              'doseSeries' => 'Series 1',
              'groupName' => 'COVID-19',
              'manufacturer' => 'TEST MANUFACTURER',
              'note' => 'Sample Immunization Note.',
              'reaction' => 'Other',
              'shortDescription' => 'SARS-COV-2 (COVID-19) vaccine, mRNA, spike protein, LNP, preservative free, 30' \
                                    ' mcg/0.3mL dose' }
          )
        end
      end

      context 'when an immunization group name is COVID-19 and there is no manufacturer provided' do
        it 'sets manufacturer to nil' do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 14, number: 1 } }
          end

          covid_no_manufacturer_immunization = response.parsed_body['data'].select do |i|
            i['id'] == 'I2-LJAZCGMN3BZVQVKQCVL7KMTHJA000000'
          end

          expect(covid_no_manufacturer_immunization.dig(0, 'attributes')).to eq(
            { 'cvxCode' => 213,
              'date' => '2021-05-09T09:59:25Z',
              'doseNumber' => 'Series 1',
              'doseSeries' => 'Series 1',
              'groupName' => 'COVID-19',
              'manufacturer' => nil,
              'note' => 'Sample Immunization Note.',
              'reaction' => 'Other',
              'shortDescription' => 'SARS-COV-2 (COVID-19) vaccine, mRNA, spike protein, LNP, preservative free, 30' \
                                    ' mcg/0.3mL dose' }
          )
        end

        it 'increments statsd' do
          expect do
            VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
              get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 14, number: 1 } }
            end
          end.to trigger_statsd_increment('mobile.immunizations.covid_manufacturer_missing', times: 1)
        end
      end

      context 'when an immunization group name is not COVID-19 and there is a manufacturer provided' do
        it 'sets manufacturer to nil' do
          immunizations_request_non_covid_with_manufacturer_paginated
          expect(response.parsed_body['data'][0]['attributes']).to eq(
            { 'cvxCode' => 88,
              'date' => '2019-02-24T09:59:25Z',
              'doseNumber' => 'Series 1',
              'doseSeries' => 'Series 1',
              'groupName' => 'FLU',
              'manufacturer' => nil,
              'note' => 'Sample Immunization Note.',
              'reaction' => 'Other',
              'shortDescription' => 'Influenza, seasonal, injectable, preservative free' }
          )
        end
      end

      context 'when an immunization group name is not COVID-19 and there is no manufacturer provided' do
        it 'sets manufacturer to nil' do
          immunizations_request_non_covid_paginated
          expect(response.parsed_body['data'][0]['attributes']).to eq(
            { 'cvxCode' => 88,
              'date' => '2014-01-26T09:59:25Z',
              'doseNumber' => 'Series 1',
              'doseSeries' => 'Series 1',
              'groupName' => 'FLU',
              'manufacturer' => nil,
              'note' => 'Sample Immunization Note.',
              'reaction' => 'Other',
              'shortDescription' => 'Influenza, seasonal, injectable, preservative free' }
          )
        end
      end
    end

    describe 'pagination' do
      it 'defaults to the first page with ten results per page', :aggregate_failures do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: nil
        end

        ids = response.parsed_body['data'].pluck('id')

        # these are the last ten records in the vcr cassette
        expected_ids = %w[I2-QGX75BMCEGXFC57E47NAWSKSBE000000
                          I2-LJAZCGMN3BZVQVKQCVL7KMTHJA000000
                          I2-R5T5WZ3D6UNCTRUASZ6N6IIVXM000000
                          I2-7JXLIQNPFQ6UNKAHYRLOGQBDOM000000
                          I2-XTVY4IDSEUWVYC25SST25RG5KU000000
                          I2-SMRNQOX7DLAPOZBY4XMAOMQKX4000000
                          I2-ZADCZ325X75FWLZPJA7P2HZEQA000000
                          I2-I3ONOUAJAMKX53U6O47NNBSP4E000000
                          I2-B5JBSVYHGRPUHI4NQCXYBVDXLM000000
                          I2-2LHIGUUW23DRPLBKWXTFDWCYSQ000000]

        expect(ids).to match_array(expected_ids)
      end

      it 'returns the correct page and number of records' do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 2, number: 3 } }
        end

        ids = response.parsed_body['data'].pluck('id')

        # these are the fifth and sixth from last records in the vcr cassette
        expect(ids).to eq(%w[I2-XTVY4IDSEUWVYC25SST25RG5KU000000 I2-SMRNQOX7DLAPOZBY4XMAOMQKX4000000])
      end
    end

    describe 'record order' do
      it 'orders records by descending date' do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 15, number: 1 } }
        end

        dates = response.parsed_body['data'].collect { |i| i['attributes']['date'] }
        expect(dates).to contain_exactly('2022-03-13T09:59:25Z', '2021-05-09T09:59:25Z', '2021-04-18T09:59:25Z',
                                         '2020-03-01T09:59:25Z', '2020-03-01T09:59:25Z', '2019-02-24T09:59:25Z',
                                         '2018-02-18T09:59:25Z', '2017-02-12T09:59:25Z', '2016-02-07T09:59:25Z',
                                         '2015-02-01T09:59:25Z', '2014-01-26T09:59:25Z')
      end
    end

    describe 'caching' do
      context 'when data is not cached' do
        it 'calls service' do
          expect_any_instance_of(Mobile::V0::LighthouseHealth::Service).to receive(:get_immunizations)

          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: {}
          end
        end

        it 'calls service even when useCache is true' do
          expect_any_instance_of(Mobile::V0::LighthouseHealth::Service).to receive(:get_immunizations)

          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: { useCache: true }
          end
        end
      end

      context 'when cache is set' do
        before do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: {}
          end
        end

        it 'uses cached data instead of calling service' do
          expect_any_instance_of(Mobile::V0::LighthouseHealth::Service).not_to receive(:get_immunizations)

          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: {}
          end
        end

        it 'does not use cache when useCache is false' do
          expect_any_instance_of(Mobile::V0::LighthouseHealth::Service).to receive(:get_immunizations)

          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: { useCache: false }
          end
        end
      end
    end

    describe 'when multiple items have same date' do
      context 'date is available' do
        it 'returns items in alphabetical order by group name' do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 10 } }
          end

          expect(response.parsed_body['data'][3]['attributes']).to eq(
            { 'cvxCode' => 88,
              'date' => '2020-03-01T09:59:25Z',
              'doseNumber' => 'Series 1',
              'doseSeries' => 'Series 1',
              'groupName' => 'FLU',
              'manufacturer' => nil,
              'note' => 'Sample Immunization Note.',
              'reaction' => 'Other',
              'shortDescription' => 'Influenza, seasonal, injectable, preservative free' }
          )
          expect(response.parsed_body['data'][4]['attributes']).to eq(
            { 'cvxCode' => 139,
              'date' => '2020-03-01T09:59:25Z',
              'doseNumber' => 'Series 1',
              'doseSeries' => 'Series 1',
              'groupName' => 'Td',
              'manufacturer' => nil,
              'note' => 'Sample Immunization Note.',
              'reaction' => 'Other',
              'shortDescription' => 'Td (adult) preservative free' }
          )
        end
      end

      context 'date is missing' do
        it 'returns items in alphabetical order by group name with missing date items at end of list' do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations_date_missing',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 4 } }
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

      context 'VACCINE GROUP is not included in vaccine code display' do
        before do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations_vaccine_codes',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers
          end
        end

        context '2 vaccine codes exists' do
          it 'returns second coding display' do
            expect(response.parsed_body['data'][0]['attributes']).to eq(
              { 'cvxCode' => 140,
                'date' => '2023-03-13T09:59:25Z',
                'doseNumber' => 'Series 1',
                'doseSeries' => 'Series 1',
                'groupName' => 'FLU',
                'manufacturer' => nil,
                'note' => 'Sample Immunization Note.',
                'reaction' => 'Other',
                'shortDescription' => 'Influenza, seasonal, injectable, preservative free' }
            )
          end
        end

        context 'only 1 vaccine code exists' do
          it 'returns first coding display' do
            expect(response.parsed_body['data'][1]['attributes']).to eq(
              { 'cvxCode' => 140,
                'date' => '2022-03-13T09:59:25Z',
                'doseNumber' => 'Series 1',
                'doseSeries' => 'Series 1',
                'groupName' => 'INFLUENZA, SEASONAL, INJECTABLE, PRESERVATIVE FREE',
                'manufacturer' => nil,
                'note' => 'Sample Immunization Note.',
                'reaction' => 'Other',
                'shortDescription' => 'Influenza, seasonal, injectable, preservative free' }
            )
          end
        end
      end
    end
  end
end
