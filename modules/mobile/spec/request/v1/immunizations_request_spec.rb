# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/helpers/sis_session_helper'
require_relative '../../support/matchers/json_schema_matcher'

RSpec.describe 'immunizations', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(icn: '9000682') }
  let(:rsa_key) { "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAmdq2dVE93zsNOZ2vC1mL4kLUWqcq6jldLb3VTaJjiuyodKAH\nletsiMCh+seA2O7XiKGX7EQU+70lzobFhnwonBFpuDp7rlAUsANais3PyB/iS7Md\n5ER9NW4xtQUefDZa6CE4KH8pcJpsj6xYYs2UOLtkle6SSDLWr7db29U6xR4aBucl\nvae/Or52CqtRo6FB/IAM0NQOWaNbvwYKnqXckhIbLzIkt2BGybwj9sEzHSFVnF6T\n9tUR5V5yQ+pef10gQYgQGEvIItQ91yrz/hayTwzPhBcd63B+mP9t0fGsb72DviN5\nz7g+SBdvpJdake4HniVyGeW6sDy8NLX6G1A90QIDAQABAoIBAFfjDUlVAFANjo90\nGPMV0weL/3xNdAFahXTEtR1k/xH0AIKmi87DLjusNptn7Z1+Slb9YCiR956aPQeO\nCzW4pQYKGGcp2U8I5dhqAgW6bdA3DnEJv7COwyuLaA+s/e4cqq9hko/nnAd73znv\nTIocP2hs+5d+McfWarbzuiCI3MqOdafJsS7bbS7ILSSlAhZHdgC3aoajb99j1ugX\n/mcfiIaXwsd9caraKuUDDl3mThLf+Enlw/0kFu1L7a/+AtLPQiWCd2hbBU1ZdugB\nmgUfmewKrTnjq5JgIAJAZInUK2SLgIxPI1lkYBOvCjUGHdiBWE75XDrQtrLkaCa7\nvUDGXjECgYEAy0jx8A7cshnBfY2K/PcF/R2kq18swK6Beqx/U5M3m9uH1lwGSMvv\nidvdGRLTV4h/U6W9WgPm16IrBAN8DbJSmqYlOaCxXYemVz3AjXMMU1FnsPqxNEUw\n0AY0qilp7P51ndwJ8IKYa90NVF40XmOKetNnoIkQyj7LmcTHpLX1240CgYEAwcBS\nTDXztC79gSoI6zNZPqWHo5GMBAJSHs7Eg845CKjqouxLDbvOkqlMb87iL2iGxSqQ\nsUZ/xvm0lUAOj+zYRMMo0Qu29hMbw6VwwoZoJjIOLAnHQCwZ0sIi/dl5ElYpVK7g\nlWvz3PLPbBg71mjqUw4j/jC6j5qX3ZN4OZ2luFUCgYANF8SlXn+uZORGbuBdzJcx\nJ0Cc3QNn4ZVrTkLhIiE5w5jrIIAzHhdufJ+v5rt/7sWsoIcijg/HIaW9m2/Y/fw+\nA6dwH75stLjs84g8VAWeNCcGig7xu+cZ7txjfUlaP0VaBnsJZ4/jmpgqL+sVjTm1\nEXqiJ1HShNreK4NkQ2fzXQKBgQCFjD/twf5yQzV/c27kV+d68/Pzfd5J4SOjkpgH\n1fygCHZ6yG7PT5WKp+FE7BAh52WFv9ouJ07p4rJjcdzXvcQwWWjn9rAtG2y2xXFc\n0/Iz6aq1FiReCkfeauxdlyoJxpQEh+nLdLaJpF/uvSF5n6VsjEGo8wOU+lUVaJGk\n/RH+ZQKBgEgaDkncaIAY86EGfWWKnleN7/SST9YhDHxXkt6ylFdl2XdrwyLkOspz\nFGEKTc1a/FJKpicXR5c3fbRXT+QAr0MX3a0k4RkfACOipf/a0d9tjKIju+fIDnSs\nN0KhVF8ND3FmJUwFF1FkqyRVj0HJBYPIAgkWaCqBPzCL/RsubFox\n-----END RSA PRIVATE KEY-----\n" }

  before do
    allow(File).to receive(:read).and_return(rsa_key)
    Timecop.freeze(Time.zone.parse('2021-10-20T15:59:16Z'))
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
        # TODO: this should use the matcher helper instead (was throwing an Oj::ParseError)
        # expect().to match_json_schema('immunizations')
        expected_response = { 'data' =>
                               [{ 'id' => 'I2-QGX75BMCEGXFC57E47NAWSKSBE000000',
                                  'type' => 'immunization',
                                  'attributes' =>
                                   { 'cvxCode' => 88,
                                     'date' => '2022-03-13T09:59:25Z',
                                     'doseNumber' => 'Series 1',
                                     'doseSeries' => 'Series 1',
                                     'groupName' => 'FLU',
                                     'manufacturer' => nil,
                                     'note' => 'Sample Immunization Note.',
                                     'reaction' => 'Other',
                                     'shortDescription' => 'Influenza, seasonal, injectable, preservative free' },
                                  'relationships' => { 'location' => { 'data' => nil,
                                                                       'links' => { 'related' => nil } } } }],
                              'meta' => { 'pagination' => { 'currentPage' => 1, 'perPage' => 1, 'totalPages' => 11,
                                                            'totalEntries' => 11 } } }

        expect(response.parsed_body).to eq(expected_response)
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

    describe 'vaccine group name and manufacturer population' do
      let(:immunizations_request_non_covid_paginated) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 11 } }
        end
      end
      let(:immunizations_request_covid_paginated) do

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
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 3 } }
          end
          p "Immunization test output: #{response.parsed_body}"
          expect(response.parsed_body['data'][0]['attributes']).to eq(
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
          immunizations_request_covid_no_manufacturer_paginated
          p "Immunization test output: #{response.parsed_body}"

          expect(response.parsed_body['data'][0]['attributes']).to eq(
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
              get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 3 } }
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

        ids = response.parsed_body['data'].map { |i| i['id'] }

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

        expect(ids).to eq(expected_ids)
      end

      it 'returns the correct page and number of records' do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 2, number: 3 } }
        end

        ids = response.parsed_body['data'].map { |i| i['id'] }

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
        expect(dates).to eq(['2022-03-13T09:59:25Z',
                             '2021-05-09T09:59:25Z',
                             '2021-04-18T09:59:25Z',
                             '2020-03-01T09:59:25Z',
                             '2020-03-01T09:59:25Z',
                             '2019-02-24T09:59:25Z',
                             '2018-02-18T09:59:25Z',
                             '2017-02-12T09:59:25Z',
                             '2016-02-07T09:59:25Z',
                             '2015-02-01T09:59:25Z',
                             '2014-01-26T09:59:25Z'])
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
