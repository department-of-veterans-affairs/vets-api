# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/ppms/ppms',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe FacilitiesApi::V2::PPMS::Client, team: :facilities, vcr: vcr_options do
  let(:client) { FacilitiesApi::V2::PPMS::Client.new }
  let(:url) { Settings.ppms.url }
  let(:path) { '/dws/v1.0/ProviderLocator' }
  let(:params) do
    {
      lat: 40.415217,
      long: -74.057114,
      radius: 200
    }.with_indifferent_access
  end
  let(:fake_response) { double('fake_response') }
  let(:error_response) do
    {
      status: 500,
      detail: 'An error has occurred.',
      code: 'PPMS_502',
      source: nil
    }
  end
  let(:provider_attributes) do
    {
      acc_new_patients: 'true',
      address_city: 'BELFORD',
      address_postal_code: '07718-1042',
      address_state_province: 'NJ',
      address_street: '55 LEONARDVILLE RD',
      care_site: 'ROBERT C LILLIE',
      caresite_phone: '732-787-4747',
      contact_method: nil,
      email: nil,
      fax: nil,
      gender: 'Male',
      latitude: 40.414248,
      longitude: -74.097581,
      main_phone: nil,
      miles: 2.5153,
      provider_identifier: '1437189941',
      provider_name: 'LILLIE, ROBERT C'
    }
  end

  context 'StatsD notifications' do
    context 'PPMS responds Successfully' do
      it "sends a 'facilities.ppms.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:measure)
        allow(StatsD).to receive(:increment)

        expect(StatsD).to receive(:measure).with(
          'facilities.ppms.provider_locator',
          kind_of(Numeric),
          hash_including(
            tags: %w[facilities.ppms facilities.ppms.radius:200 facilities.ppms.results:11]
          )
        )
        expect(StatsD).to receive(:increment).with(
          'facilities.ppms.response.total',
          hash_including(
            tags: [
              'http_status:200'
            ]
          )
        )
        expect do
          FacilitiesApi::V2::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
        end.to instrument('facilities.ppms.v2.request.faraday')
      end
    end

    context 'PPMS responds with a Failure', vcr: vcr_options.merge(
      cassette_name: 'facilities/ppms/ppms_500',
      match_requests_on: [:method]
    ) do
      it "sends a 'facilities.ppms.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:measure)
        allow(StatsD).to receive(:increment)

        expect(StatsD).to receive(:measure).with(
          'facilities.ppms.provider_locator',
          kind_of(Numeric),
          hash_including(
            tags: %w[facilities.ppms facilities.ppms.radius:200 facilities.ppms.results:0]
          )
        )
        expect(StatsD).to receive(:increment).with(
          'facilities.ppms.response.total',
          hash_including(
            tags: [
              'http_status:500'
            ]
          )
        )
        expect(StatsD).to receive(:increment).with(
          'facilities.ppms.response.failures',
          hash_including(
            tags: [
              'http_status:500'
            ]
          )
        )
        expect do
          FacilitiesApi::V2::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
        end.to raise_error(
          Common::Exceptions::BackendServiceException
        ).and instrument('facilities.ppms.v2.request.faraday')
      end
    end
  end

  context 'with an http timeout' do
    it 'logs an error and raise GatewayTimeout' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      expect do
        FacilitiesApi::V2::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
      end.to raise_error(Common::Exceptions::GatewayTimeout)
    end
  end

  context 'with an unknown error from PPMS', vcr: vcr_options.merge(
    cassette_name: 'facilities/ppms/ppms_500',
    match_requests_on: %i[method]
  ) do
    it 'raises BackendUnhandledException when errors happen' do
      expect { FacilitiesApi::V2::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X'])) }
        .to raise_error(Common::Exceptions::BackendServiceException) do |e|
          expect(e.response_values).to match(error_response)
          expect(e.message).to match(/PPMS_502/)
        end
    end
  end

  context 'with a stack trace from PPMS', vcr: vcr_options.merge(
    cassette_name: 'facilities/ppms/ppms_500_stack_trace',
    match_requests_on: [:method]
  ) do
    it 'raises BackendUnhandledException when PPMS raises a stack trace' do
      expect { FacilitiesApi::V2::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X'])) }
        .to raise_error(Common::Exceptions::BackendServiceException) do |e|
          error_response[:source] = 'Operation is not valid due to the current state of the object.'
          expect(e.response_values).to match(error_response)
          expect(e.message).to match(/PPMS_502/)
      end
    end
  end

  context 'with a Geocode error from PPMS', vcr: vcr_options.merge(
    cassette_name: 'facilities/ppms/ppms_500_geo_error',
    match_requests_on: [:method]
  ) do
    it 'raises BackendUnhandledException when PPMS raises a stack trace' do
      expect { FacilitiesApi::V2::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X'])) }
        .to raise_error(Common::Exceptions::BackendServiceException) do |e|
          error_response[:detail] = 'Unable to Geocode the given address. For At Home Services Search ' \
                                    'you must provide a full Street Address and City as well as a State or ZipCode.'
          expect(e.response_values).to match(error_response)
          expect(e.message).to match(/Unable to Geocode the given address/)
        end
    end
  end

  context 'with an empty result', vcr: vcr_options.merge(
    cassette_name: 'facilities/ppms/ppms_empty_search',
    match_requests_on: [:method]
  ) do
    it 'returns an empty array' do
      expect(described_class.new.provider_locator(params.merge(specialties: ['213E00000X']))).to be_empty
    end
  end

  describe 'base params' do
    let(:test_params) do
      {
        address: '40.415217,-74.057114',
        homeHealthSearch: 0,
        maxResults: 11,
        radius: 200,
        specialtycode1: 'Code1',
        telehealthSearch: 0
      }
    end

    before do
      allow(fake_response).to receive(:body)
    end

    describe 'Clamping Results' do
      it 'page and per_page is not required' do
        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)

        client.provider_locator(params.merge(specialties: %w[Code1]))
      end

      it 'returns paginated results' do
        test_params.merge!(pageNumber: 1, pageSize: 10)

        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)

        client.provider_locator(params.merge(specialties: %w[Code1], page: 1, per_page: 10))
      end

      it 'maxResults cannot be greater then 50' do
        test_params.merge!(maxResults: 50, pageNumber: 1, pageSize: 60)
        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)
        client.provider_locator(params.merge(specialties: %w[Code1], page: 1, per_page: 60))

        test_params.merge!(pageNumber: 60, pageSize: 1)
        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)
        client.provider_locator(params.merge(specialties: %w[Code1], page: 60, per_page: 1))
      end

      it 'maxResults cannot be less than 2' do
        test_params.merge!(maxResults: 2, pageNumber: 1, pageSize: 0)
        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)
        client.provider_locator(params.merge(specialties: %w[Code1], page: 1, per_page: 0))

        test_params.merge!(pageNumber: 0)
        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)
        client.provider_locator(params.merge(specialties: %w[Code1], page: 0, per_page: 0))

        test_params.merge!(pageNumber: -10, pageSize: 1)
        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)
        client.provider_locator(params.merge(specialties: %w[Code1], page: -10, per_page: 1))
      end
    end

    describe 'Clamping Radius' do
      it 'limits radius to 500' do
        expect(client).to receive(:perform).with(:get, path, test_params.merge!(radius: 500)).and_return(fake_response)

        client.provider_locator(params.merge(specialties: %w[Code1], radius: 600))
      end

      it 'limits radius to 1' do
        expect(client).to receive(:perform).with(:get, path, test_params.merge!(radius: 1)).and_return(fake_response)

        client.provider_locator(params.merge(specialties: %w[Code1], radius: 1))
      end
    end

    describe 'Sanitizing Longitude and Latitude' do
      it 'only sends 5 digits of accuracy to ppms' do
        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)

        client.provider_locator(params.merge(specialties: %w[Code1], lat: 40.415217178901234, long: -74.05711418901234))
      end
    end
  end

  describe '#facility_service_locator' do
    let(:path) { '/dws/v1.0/FacilityServiceLocator' }
    let(:test_params) do
      {
        address: '40.415217,-74.057114',
        homeHealthSearch: 0,
        maxResults: 10,
        pageNumber: 1,
        pageSize: 10,
        radius: 200,
        specialtycode1: 'Code1',
        specialtycode2: 'Code2',
        specialtycode3: 'Code3',
        specialtycode4: 'Code4',
        specialtycode5: 'Code5',
        telehealthSearch: 0
      }
    end

    describe 'Require between 1 and 5 Specialties' do
      it 'accepts up to 5 specialties' do
        allow(fake_response).to receive(:body)
        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)

        client.facility_service_locator(params.merge(specialties: %w[Code1 Code2 Code3 Code4 Code5]))
      end

      it 'ignores more than 5 specialties' do
        allow(fake_response).to receive(:body)
        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)

        client.facility_service_locator(params.merge(specialties: %w[Code1 Code2 Code3 Code4 Code5 Code6]))
      end
    end

    describe 'Paginated Responses' do
      describe 'Page 1' do
        let!(:response) do
          FacilitiesApi::V2::PPMS::Client.new.facility_service_locator(
            params.merge(
              maxResults: 20,
              specialties: ['213E00000X'],
              telehealthSearch: 0,
              page: 1,
              per_page: 20
            )
          )
        end

        it 'is expected to have the following attributes' do
          expect(response[0]).to have_attributes(provider_attributes)
        end

        it 'is expected to contain the following provider IDs' do
          expect(response.collect(&:provider_identifier)).to contain_exactly(
            '1437189941',
            '1598735631',
            '1598053944',
            '1689617748',
            '1154383230',
            '1083043236',
            '1225099500',
            '1407929631',
            '1770840068',
            '1033125174',
            '1780603902',
            '1275569956',
            '1578676821',
            '1790707057',
            '1740269273',
            '1851318745',
            '1750368486',
            '1114903713',
            '1730252859',
            '1154383230'
          )
        end
      end

      describe 'Page 2' do
        let!(:response) do
          FacilitiesApi::V2::PPMS::Client.new.facility_service_locator(
            params.merge(
              maxResults: 20,
              specialties: ['213E00000X'],
              page: 2,
              per_page: 20
            )
          )
        end

        it 'is expected to contain the following provider IDs' do
          expect(response.collect(&:provider_identifier)).to contain_exactly(
            '1518224773',
            '1154383230',
            '1093110744',
            '1588687065',
            '1801125703',
            '1083043236',
            '1083043236',
            '1639292212',
            '1194839274',
            '1194801084',
            '1679504427',
            '1992799464',
            '1255501938',
            '1083043236',
            '1164461927',
            '1275625261',
            '1679589261',
            '1063819092',
            '1417171638',
            '1265505630'
          )
        end
      end

      describe 'Page 3' do
        let!(:response) do
          FacilitiesApi::V2::PPMS::Client.new.facility_service_locator(
            params.merge(
              maxResults: 20,
              specialties: ['213E00000X'],
              page: 3,
              per_page: 20
            )
          )
        end

        it 'is expected to contain the following provider IDs' do
          expect(response.collect(&:provider_identifier)).to contain_exactly(
            '1962683235',
            '1831187426',
            '1831187426',
            '1851318745',
            '1194188565',
            '1851318745',
            '1669466207',
            '1013902428',
            '1548581069',
            '1154792364',
            '1295872661',
            '1205831450',
            '1316163298',
            '1487004552',
            '1083043236',
            '1083043236',
            '1518230663',
            '1083043236',
            '1548209356',
            '1912382888'
          )
        end
      end
    end
  end

  describe '#provider_locator' do
    describe 'Require between 1 and 5 Specialties' do
      let(:test_params) do
        {
          address: '40.415217,-74.057114',
          homeHealthSearch: 0,
          maxResults: 11,
          radius: 200,
          specialtycode1: 'Code1',
          specialtycode2: 'Code2',
          specialtycode3: 'Code3',
          specialtycode4: 'Code4',
          specialtycode5: 'Code5',
          telehealthSearch: 0
        }
      end

      it 'accepts upto 5 specialties' do
        allow(fake_response).to receive(:body)
        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)

        client.provider_locator(params.merge(specialties: %w[Code1 Code2 Code3 Code4 Code5]))
      end

      it 'ignores more than 5 specialties' do
        allow(fake_response).to receive(:body)
        expect(client).to receive(:perform).with(:get, path, test_params).and_return(fake_response)

        client.provider_locator(params.merge(specialties: %w[Code1 Code2 Code3 Code4 Code5 Code6]))
      end
    end

    it 'returns a list of providers' do
      r = FacilitiesApi::V2::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
      expect(r.length).to be 11
      expect(r[0]).to have_attributes(provider_attributes)
    end
  end

  describe '#pos_locator' do
    it 'finds places of service' do
      r = FacilitiesApi::V2::PPMS::Client.new.pos_locator(params)
      expect(r.length).to be 11
      expect(r[0]).to have_attributes(provider_attributes.merge(
                                        acc_new_patients: 'false',
                                        address_city: 'ATLANTIC HIGHLANDS',
                                        address_postal_code: '07716',
                                        address_street: '2 BAYSHORE PLZ',
                                        care_site: 'BAYSHORE PHARMACY',
                                        caresite_phone: '732-291-2900',
                                        gender: 'NotSpecified',
                                        latitude: 40.409114,
                                        longitude: -74.041849,
                                        miles: 1.0277,
                                        pos_codes: %w[17 20],
                                        provider_identifier: '1225028293',
                                        provider_name: 'BAYSHORE PHARMACY'
                                      ))
    end
  end

  describe '#specialties', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_specialties') do
    it 'returns some Specialties' do
      r = FacilitiesApi::V2::PPMS::Client.new.specialties
      expect(r.each_with_object(Hash.new(0)) do |specialty, count|
        count[specialty.specialty_code] += 1
      end).to match(
        '101Y00000X' => 1,
        '101YA0400X' => 1,
        '101YM0800X' => 1,
        '101YP1600X' => 1,
        '101YP2500X' => 1,
        '101YS0200X' => 1
      )
    end
  end

  describe '#fetch_lat_long_and_radius' do
    describe 'Valid values' do
      it 'returns latitude, longitude, and radius as expected' do
        test_params = { lat: 40.415217, long: -74.057114, radius: 200 }
        latitude, longitude, radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(latitude).to eq(40.415217)
        expect(longitude).to eq(-74.057114)
        expect(radius).to eq(200)
      end

      it 'accepts latitude and longitude as string representations of floats' do
        test_params = { lat: '40.415217', long: '-74.057114', radius: '200' }
        latitude, longitude, radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(latitude).to eq(40.415217)
        expect(longitude).to eq(-74.057114)
        expect(radius).to eq(200)
      end

      it 'rounds latitude and longitude to 6 decimal places' do
        test_params = { lat: 40.4152171234567, long: -74.0571141234567, radius: 200 }
        latitude, longitude, _radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(latitude).to eq(40.415217)
        expect(longitude).to eq(-74.057114)
      end

      it 'clamps radius to minimum of 1' do
        test_params = { lat: 40.415217, long: -74.057114, radius: 0.5 }
        _latitude, _longitude, radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(radius).to eq(1)
      end

      it 'clamps radius to maximum of 500' do
        test_params = { lat: 40.415217, long: -74.057114, radius: 600 }
        _latitude, _longitude, radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(radius).to eq(500)
      end

      it 'handles positive and negative coordinates' do
        test_params = { lat: -33.8688, long: 151.2093, radius: 50 }
        latitude, longitude, radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(latitude).to eq(-33.8688)
        expect(longitude).to eq(151.2093)
        expect(radius).to eq(50)
      end

      it 'accepts latitude parameter as alternative to lat' do
        test_params = { latitude: 40.415217, long: -74.057114, radius: 200 }
        latitude, _longitude, _radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(latitude).to eq(40.415217)
      end

      it 'accepts longitude parameter as alternative to long' do
        test_params = { lat: 40.415217, longitude: -74.057114, radius: 200 }
        _latitude, longitude, _radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(longitude).to eq(-74.057114)
      end

      it 'prefers lat over latitude when both are provided' do
        test_params = { lat: 40.415217, latitude: 50.0, long: -74.057114, radius: 200 }
        latitude, _longitude, _radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(latitude).to eq(40.415217)
      end

      it 'prefers long over longitude when both are provided' do
        test_params = { lat: 40.415217, long: -74.057114, longitude: 100.0, radius: 200 }
        _latitude, longitude, _radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(longitude).to eq(-74.057114)
      end

      it 'handles integer radius values' do
        test_params = { lat: 40.415217, long: -74.057114, radius: 150 }
        _latitude, _longitude, radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(radius).to eq(150)
      end

      it 'handles float radius values that convert to minimum after clamping' do
        test_params = { lat: 40.415217, long: -74.057114, radius: 0 }
        _latitude, _longitude, radius = client.send(:fetch_lat_long_and_radius, test_params)

        expect(radius).to eq(1)
      end
    end

    describe 'Invalid values' do
      it 'raises InvalidFieldValue for non-float radius' do
        test_params = { lat: 40.415217, long: -74.057114, radius: 'invalid' }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('radius')
        }
      end

      it 'raises InvalidFieldValue for non-float latitude' do
        test_params = { lat: 'not_a_number', long: -74.057114, radius: 200 }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('lat')
        }
      end

      it 'raises InvalidFieldValue for non-float longitude' do
        test_params = { lat: 40.415217, long: 'not_a_number', radius: 200 }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('long')
        }
      end

      it 'raises InvalidFieldValue when radius is nil' do
        test_params = { lat: 40.415217, long: -74.057114, radius: nil }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('radius')
        }
      end

      it 'raises InvalidFieldValue when latitude is nil' do
        test_params = { lat: nil, long: -74.057114, radius: 200 }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('lat')
        }
      end

      it 'raises InvalidFieldValue when longitude is nil' do
        test_params = { lat: 40.415217, long: nil, radius: 200 }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('long')
        }
      end

      it 'raises InvalidFieldValue for radius with special characters' do
        test_params = { lat: 40.415217, long: -74.057114, radius: '100$' }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('radius')
        }
      end

      it 'raises InvalidFieldValue for latitude with special characters' do
        test_params = { lat: '40.415217@', long: -74.057114, radius: 200 }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('lat')
        }
      end

      it 'raises InvalidFieldValue for longitude with special characters' do
        test_params = { lat: 40.415217, long: '-74.057114!', radius: 200 }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('long')
        }
      end

      it 'raises InvalidFieldValue for empty string radius' do
        test_params = { lat: 40.415217, long: -74.057114, radius: '' }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('radius')
        }
      end

      it 'raises InvalidFieldValue for empty string latitude' do
        test_params = { lat: '', long: -74.057114, radius: 200 }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('lat')
        }
      end

      it 'raises InvalidFieldValue for empty string longitude' do
        test_params = { lat: 40.415217, long: '', radius: 200 }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
          expect(error.field).to eq('long')
        }
      end

      it 'raises error when radius parameter is missing' do
        test_params = { lat: 40.415217, long: -74.057114 }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.to raise_error(KeyError)
      end

      it 'does not raise error when latitude is missing but lat is present' do
        test_params = { lat: 40.415217, long: -74.057114, radius: 200 }

        expect do
          client.send(:fetch_lat_long_and_radius, test_params)
        end.not_to raise_error
      end
    end
  end
end
