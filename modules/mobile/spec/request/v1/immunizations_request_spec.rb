# frozen_string_literal: true

require 'rails_helper'
# require 'committee/schema_validator/open_api_3/response_validator'
require_relative '../../support/helpers/sis_session_helper'
require_relative '../../support/matchers/json_schema_matcher'

RSpec.describe 'immunizations', type: :request do
  include JsonSchemaMatchers
  include Committee::Rails::Test::Methods

  let!(:user) { sis_user(icn: '9000682') }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before do
    allow(File).to receive(:read).and_return(rsa_key.to_s)
    Timecop.freeze(Time.zone.parse('2021-10-20T15:59:16Z'))
  end

  after { Timecop.return }

  def hashify_schema(schema)
    acc = {}
    schema.to_h.each_pair do |k, v|
      if v.is_a?(Openapi3Parser::Node::Object) || v.is_a?(Openapi3Parser::Node::Map)
        h = hashify_schema(v)
        acc[k] = h
      elsif v.is_a?(Openapi3Parser::Node::Array)
        acc[k] = v.to_a
      else
        acc[k] = v
      end
    end
    acc
  end

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

      context 'with rspec openapi' do
        it 'validates the expected schema' do
          RSpec::OpenAPI.path = 'modules/mobile/docs/openapi.yaml'
          expect(response).to match_response_schema('modules/mobile/docs/openapi.yaml')
        end

        it 'catches errors'

        it 'works with simplified data'

        it 'works with refs'
      end

      context 'with Openapi3Parser' do
        it 'validates the expected schema' do
          # TODO: this should use the matcher helper instead (was throwing an Oj::ParseError)
          # expect(response.parsed_body).to match_json_schema('modules/mobile/docs/schemas/v1/Immunizations.yml', strict: true)
          # schema_file = 'modules/mobile/docs/schemas/v1/Immunizations.yml'
          schema_file = 'modules/mobile/docs/openapi.yaml'
          file = File.open(schema_file)
          # can also handle permitted classes at gem level: https://stackoverflow.com/questions/71332602/upgrading-to-ruby-3-1-causes-psychdisallowedclass-exception-when-using-yaml-lo
          # json_schema = YAML.load_file('modules/mobile/docs/schemas/v1/Immunizations.yml', permitted_classes: [Matrix, OpenStruct, Symbol, Time])
          json_schema = Openapi3Parser.load(file)

          # json_schema = Apivore::SwaggerChecker.instance_for(schema_file)
          # expect(json_schema).to validate(:get, '/mobile/v1/health/immunizations', 200, sis_headers)

          expect(JSON::Validator.validate(json_schema.to_h, response.parsed_body)).to eq(true)

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

        it 'fails when the schema does not match' do
          schema_file = 'modules/mobile/docs/openapi.yaml'
          file = File.open(schema_file)
          json_schema = Openapi3Parser.load(file)
  
          # this is missing id
          expected_response = {
            'data' => [{
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

          @success_schema = json_schema.paths["/v0/health/immunizations"].get.responses['200']
          # schema = hashify_schema(@success_schema)
          validator = Committee::SchemaValidator::OpenAPI3::ResponseValidator.new(@success_schema)

          # relevant_schema = schema.dig('content', 'application/json', 'schema', 'properties')
          # errors = JSON::Validator.fully_validate(relevant_schema, expected_response.to_json)
          # expect(response.body).to match_json_schema(relevant_schema)
          expect(validator.call(response)).to be_nil

          # expect(errors).to eq([])
        end

        it 'works with a simpler test setup' do
          schema_file = 'modules/mobile/docs/openapi.yaml'
          file = File.open(schema_file)
          json_schema = Openapi3Parser.load(file)
          @success_schema = json_schema.paths["/test"].get.responses['200']
          # schema = hashify_schema(@success_schema)

          expected_response = {
            'data' => {
            }
          }

          schema = Openapi3Parser.load_file('path/to/your/openapi.yaml')
          errors = JSON::Validator.fully_validate(schema.dig('content', 'application/json', 'schema', 'properties'), expected_response.to_json)
          expect(errors).to be_empty
        end

        it 'works with refs'
      end

      context 'with committee' do
        it 'validates realish schema' do
          # schema_path = "#{Rails.root}/modules/mobile/docs/openapi.yaml"
          # last_response = response
          # last_request = request
          RSpec.configure do |config|
            config.add_setting :committee_options
            config.committee_options = {
              schema_path: Rails.root.join('modules', 'mobile', 'docs', 'openapi_no_refs.yaml').to_s,
              query_hash_key: 'rack.request.query_hash',
              parse_response_by_content_type: false,
            }
          end
          # @committee_options ||= {
          #   schema_path: Rails.root.join('module', 'mobile', 'docs', 'openapi.yaml').to_s,
          #   query_hash_key: 'rack.request.query_hash',
          #   parse_response_by_content_type: false,
          # }
          # use Committee::Middleware::RequestValidation, schema_path: 'modules/mobile/docs/openapi.yaml'
          assert_schema_conform(200)
        rescue => e
          binding.pry
        end

        it 'catches errors'

        it 'works with simplified data'

        it 'works with refs'
      end

      context 'for items that do not have locations' do
        it 'has a blank relationship' do
          VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 15 } }
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
            get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 13 } }
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
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 15, number: 1 } }
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
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 13 } }
        end
      end
      let(:immunizations_request_covid_paginated) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 2 } }
        end
      end
      let(:immunizations_request_covid_no_manufacturer_paginated) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 1 } }
        end
      end
      let(:immunizations_request_non_covid_with_manufacturer_paginated) do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1, number: 6 } }
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
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: nil
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
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 2, number: 3 } }
        end

        ids = response.parsed_body['data'].map { |i| i['id'] }

        # these are the fifth and sixth from last records in the vcr cassette
        expect(ids).to eq(%w[I2-JYYSRLCG3BN646ZPICW25IEOFQ000000 I2-7PQYOMZCN4FG2Z545JOOLAVCBA000000])
      end
    end

    describe 'record order' do
      it 'orders records by descending date' do
        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 15, number: 1 } }
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
    end
  end
end
