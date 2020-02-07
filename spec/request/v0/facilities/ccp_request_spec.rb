# frozen_string_literal: true

require 'rails_helper'
require File.expand_path(
  Rails.root.join(
    'spec',
    'support',
    'shared_contexts',
    'facilities_ppms.rb'
  )
)

RSpec.describe 'Community Care Providers', type: :request do
  include_context 'Facilities PPMS'

  let(:provider) { FactoryBot.build(:provider, :from_pos_locator) }
  let(:provider_details) do
    FactoryBot.build(:provider, :from_provider_info, provider.attributes.slice(:ProviderIdentifier))
  end

  describe '#index' do
    def strong_params(wimpy_params)
      ActionController::Parameters.new(wimpy_params).permit!
    end

    let(:params) do
      {
        address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
        bbox: ['-112.54', '32.53', '-111.04', '34.03']
      }
    end

    context 'type=cc_provider' do
      let(:provider) { FactoryBot.build(:provider, :from_provider_locator) }

      it 'returns a results from the provider_locator' do
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_locator)
          .with(strong_params(params.merge(type: 'cc_provider', services: ['213E00000X'])))
          .and_return([provider])
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_info)
          .with(provider['ProviderIdentifier'])
          .and_return(provider_details)

        get '/v0/facilities/ccp', params: params.merge('type' => 'cc_provider', 'services' => ['213E00000X'])
        bod = JSON.parse(response.body)
        expect(response).to be_successful
        expect(bod).to include(fake_providers_serializer(provider, provider_details))
      end
    end

    context 'type=cc_pharmacy' do
      it 'returns results from the pos_locator' do
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_locator)
          .with(strong_params(params.merge(type: 'cc_pharmacy', services: ['3336C0003X'])))
          .and_return([provider])
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_info)
          .with(provider['ProviderIdentifier'])
          .and_return(provider_details)

        get '/v0/facilities/ccp', params: params.merge('type' => 'cc_pharmacy')
        bod = JSON.parse(response.body)
        expect(response).to be_successful
        expect(bod).to include(fake_providers_serializer(provider))
      end
    end

    context 'type=cc_walkin' do
      it 'returns results from the pos_locator' do
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:pos_locator)
          .with(strong_params(params.merge(type: 'cc_walkin')), '17')
          .and_return([provider])

        get '/v0/facilities/ccp', params: params.merge('type' => 'cc_walkin')

        bod = JSON.parse(response.body)
        expect(response).to be_successful
        expect(bod).to include(fake_providers_serializer(provider))
      end
    end

    context 'type=cc_urgent_care' do
      it 'returns results from the pos_locator' do
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:pos_locator)
          .with(
            strong_params(params.merge(type: 'cc_urgent_care')),
            '20'
          )
          .and_return([provider])

        get '/v0/facilities/ccp', params: params.merge('type' => 'cc_urgent_care')

        bod = JSON.parse(response.body)
        expect(response).to be_successful
        expect(bod).to include(fake_providers_serializer(provider))
      end
    end
  end

  describe '#show' do
    let(:provider_services_response) do
      {
        'CareSiteAddressStreet' => Faker::Address.street_address,
        'CareSiteAddressCity' => Faker::Address.city,
        'CareSiteAddressZipCode' => Faker::Address.zip,
        'CareSiteAddressState' => Faker::Address.state_abbr,
        'Latitude' => Faker::Address.latitude,
        'Longitude' => Faker::Address.longitude
      }
    end

    it 'indicates an invalid parameter' do
      get '/v0/facilities/ccp/12345'
      expect(response).to have_http_status(:bad_request)
      bod = JSON.parse(response.body)
      expect(bod['errors'].length).to be > 0
      expect(bod['errors'][0]['title']).to eq('Invalid field value')
    end

    it 'returns RecordNotFound if ppms has no record' do
      expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_info)
        .with('0000000000').and_return(nil)

      get '/v0/facilities/ccp/ccp_0000000000'
      bod = JSON.parse(response.body)
      expect(bod['errors'].length).to be > 0
      expect(bod['errors'][0]['title']).to eq('Record not found')
    end

    it 'returns a provider with services' do
      expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_info)
        .with('0000000000').and_return(provider)
      expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_services)
        .with('0000000000').and_return([provider_services_response])

      get '/v0/facilities/ccp/ccp_0000000000'
      bod = JSON.parse(response.body)
      expect(bod).to include(fake_provider_serializer(provider, provider_services_response))
    end

    it 'returns a provider without services' do
      expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_info)
        .with('0000000000').and_return(provider)
      expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_services)
        .with('0000000000').and_return(nil)

      get '/v0/facilities/ccp/ccp_0000000000'
      bod = JSON.parse(response.body)
      expect(bod).to include(fake_provider_serializer(provider))
    end
  end

  describe '#services' do
    it 'returns a provider without services' do
      specialty = {
        'SpecialtyCode' => '101Y00000X',
        'Name' => 'Counselor',
        'Grouping' => 'Behavioral Health & Social Service Providers',
        'Classification' => 'Counselor',
        'Specialization' => nil,
        'SpecialtyDescription' =>
          'A provider who is trained and educated in the performance of behavior' \
          'health services through interpersonal communications and analysis.' \
          'Training and education at the specialty level usually requires a' \
          "master's degree and clinical experience and supervision for licensure" \
          'or certification.'
      }

      expect_any_instance_of(Facilities::PPMS::Client).to receive(:specialties)
        .and_return([specialty])
      get '/v0/facilities/services'
      bod = JSON.parse(response.body)
      expect(bod).to include(specialty)
    end
  end
end
