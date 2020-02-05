# frozen_string_literal: true

RSpec.shared_context 'Facilities PPMS' do
  def fake_provider_serializer_address(attributes)
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

  def fake_provider_serializer_data(attributes)
    {
      'attributes' => {
        'acc_new_patients' => attributes[:IsAcceptingNewPatients],
        'address' => fake_provider_serializer_address(attributes),
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

  def fake_providers_serializer(provider, extras = {})
    provider = provider.attributes if provider.respond_to?(:attributes)
    extras = extras.attributes if extras.respond_to?(:attributes)

    attributes = extras.merge(provider)
    data = fake_provider_serializer_data(attributes)

    { 'data' => [data] }
  end

  def fake_provider_serializer(provider, extras = {})
    provider = provider.attributes if provider.respond_to?(:attributes)
    extras = extras.attributes if extras.respond_to?(:attributes)

    attributes = extras.merge(provider)
    data = fake_provider_serializer_data(attributes)

    { 'data' => data }
  end
end
