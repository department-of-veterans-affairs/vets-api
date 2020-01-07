# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Facilities::CcpController, type: :controller do
  def fake_address(attributes)
    if attributes.slice(
      :AddressStreet,
      :AddressCity,
      :AddressStateProvince,
      :AddressPostalCode
    ).values.all?
      {
        'street' => provider.AddressStreet,
        'city' => provider.AddressCity,
        'state' => provider.AddressStateProvince,
        'zip' => provider.AddressPostalCode
      }
    else
      {}
    end
  end

  def fake_data(attributes)
    {
      'attributes' => {
        'acc_new_patients' => attributes[:IsAcceptingNewPatients],
        'address' => fake_address(attributes),
        'caresite_phone' => attributes[:CareSitePhoneNumber],
        'email' => attributes[:Email],
        'fax' => attributes[:OrganizationFax],
        'gender' => attributes[:ProviderGender],
        'lat' => attributes[:Latitude],
        'long' => attributes[:Longitude],
        'name' => attributes[:Name],
        'phone' => attributes[:MainPhone],
        'pref_contact' => attributes[:ContactMethod],
        'specialty' => [],
        'unique_id' => attributes[:ProviderIdentifier]
      },
      'id' => "ccp_#{attributes[:ProviderIdentifier]}",
      'type' => 'cc_provider'
    }
  end

  def fake_provider_serializer(provider_hash, details_hash = {}, set = true)
    attributes = details_hash.merge(provider_hash)
    data = fake_data(attributes)
    if set
      { 'data' => [data] }
    else
      { 'data' => data }
    end
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
      let(:provider_with_details) do
        FactoryBot.build(:provider, :from_provider_info, provider.attributes.slice(:ProviderIdentifier))
      end

      it 'returns a results from the provider_locator' do
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_locator)
          .with(strong_params(params.merge(type: 'cc_provider', services: ['213E00000X'])))
          .and_return([provider])
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_info)
          .with(provider['ProviderIdentifier'])
          .and_return(provider_with_details)

        get 'index', params: params.merge('type' => 'cc_provider', 'services' => ['213E00000X'])
        bod = JSON.parse(response.body)
        expect(response).to be_successful
        expect(bod).to include(fake_provider_serializer(provider.attributes, provider_with_details.attributes))
      end
    end

    context 'type=cc_pharmacy' do
      let(:provider) { FactoryBot.build(:provider, :from_pos_locator) }
      let(:provider_with_details) do
        FactoryBot.build(:provider, :from_provider_info, provider.attributes.slice(:ProviderIdentifier))
      end

      it 'returns results from the pos_locator' do
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_locator)
          .with(strong_params(params.merge(type: 'cc_pharmacy', services: ['3336C0003X'])))
          .and_return([provider])
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_info)
          .with(provider['ProviderIdentifier'])
          .and_return(provider_with_details)

        get 'index', params: params.merge('type' => 'cc_pharmacy')
        bod = JSON.parse(response.body)
        expect(response).to be_successful
        expect(bod).to include(fake_provider_serializer(provider.attributes))
      end
    end

    context 'type=cc_walkin' do
      let(:provider) { FactoryBot.build(:provider, :from_pos_locator) }

      it 'returns results from the pos_locator' do
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:pos_locator)
          .with(strong_params(params.merge(type: 'cc_walkin')), '17')
          .and_return([provider])

        get 'index', params: params.merge('type' => 'cc_walkin')

        bod = JSON.parse(response.body)
        expect(response).to be_successful
        expect(bod).to include(fake_provider_serializer(provider.attributes))
      end
    end

    context 'type=cc_urgent_care' do
      let(:provider) { FactoryBot.build(:provider, :from_pos_locator) }

      it 'returns results from the pos_locator' do
        expect_any_instance_of(Facilities::PPMS::Client).to receive(:pos_locator)
          .with(
            strong_params(params.merge(type: 'cc_urgent_care')),
            '20'
          )
          .and_return([provider])

        get 'index', params: params.merge('type' => 'cc_urgent_care')

        bod = JSON.parse(response.body)
        expect(response).to be_successful
        expect(bod).to include(fake_provider_serializer(provider.attributes))
      end
    end
  end

  describe '#show' do
    let(:provider) { FactoryBot.build(:provider, :from_provider_info) }

    it 'indicates an invalid parameter' do
      get 'show', params: { id: '12345' }
      expect(response).to have_http_status(:bad_request)
      bod = JSON.parse(response.body)
      expect(bod['errors'].length).to be > 0
      expect(bod['errors'][0]['title']).to eq('Invalid field value')
    end

    it 'returns RecordNotFound if ppms has no record' do
      expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_info)
        .with('0000000000').and_return(nil)

      get 'show', params: { id: 'ccp_0000000000' }
      bod = JSON.parse(response.body)
      expect(bod['errors'].length).to be > 0
      expect(bod['errors'][0]['title']).to eq('Record not found')
    end

    it 'returns a provider with services' do
      provider_service = {
        'Name' => provider.Name,
        'AffiliationName' => 'TriWest - Choice',
        'RelationshipName' => 'Choice',
        'ProviderName' => provider.Name,
        'ProviderAgreementName' => nil,
        'SpecialtyName' => Faker::Construction.subcontract_category,
        'SpecialtyCode' => Faker::Alphanumeric.alphanumeric(number: 10),
        'HPP' => 'Unknown',
        'HighPerformingProvider' => 'TriWest - Choice(U)',
        'CareSiteName' => provider.Name,
        'CareSiteLocationAddress' => [
          provider.AddressStreet,
          provider.AddressCity,
          provider.AddressPostalCode,
          provider.AddressPostalCode
        ].join(', '),
        'CareSiteAddressStreet' => provider.AddressStreet,
        'CareSiteAddressStreet1' => provider.AddressStreet,
        'CareSiteAddressStreet2' => nil,
        'CareSiteAddressStreet3' => nil,
        'CareSiteAddressCity' => provider.AddressCity,
        'CareSiteAddressState' => provider.AddressPostalCode,
        'CareSiteAddressZipCode' => provider.AddressPostalCode,
        'Latitude' => provider.Latitude,
        'Longitude' => provider.Longitude,
        'CareSitePhoneNumber' => provider.CareSitePhoneNumber,
        'OrganiztionGroupName' => nil,
        'DescriptionOfService' => nil,
        'Limitation' => nil
      }.with_indifferent_access
      expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_info)
        .with('0000000000').and_return(provider)
      expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_services)
        .with('0000000000').and_return([provider_service])

      get 'show', params: { id: 'ccp_0000000000' }
      bod = JSON.parse(response.body)
      expect(bod).to include(fake_provider_serializer(provider.attributes, provider_service, false))
    end

    it 'returns a provider without services' do
      expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_info)
        .with('0000000000').and_return(provider)
      expect_any_instance_of(Facilities::PPMS::Client).to receive(:provider_services)
        .with('0000000000').and_return(nil)

      get 'show', params: { id: 'ccp_0000000000' }
      bod = JSON.parse(response.body)
      expect(bod).to include(fake_provider_serializer(provider.attributes, {}, false))
    end
  end

  describe '#services' do
    it 'returns a provider without services' do
      expect_any_instance_of(Facilities::PPMS::Client).to receive(:specialties)
        .and_return(
          [
            {
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
          ]
        )
      get 'services'
      bod = JSON.parse(response.body)
      expect(bod).to include(
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
      )
    end
  end
end
