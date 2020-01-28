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

  def fake_provider_serializer(provider_hash, details_hash = {}, set = true)
    attributes = details_hash.merge(provider_hash)
    data = fake_provider_serializer_data(attributes)
    if set
      { 'data' => [data] }
    else
      { 'data' => data }
    end
  end

end
