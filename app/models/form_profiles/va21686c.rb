# frozen_string_literal: true

module VA21686c
  class FormFullName
    include Virtus.model

    attribute :first, String
    attribute :middle, String
    attribute :last, String
    # TODO:  does service ever return suffix?
  end

  class FormContactInformation
    include Virtus.model

    attribute :mailing_address, ::FormAddress
    attribute :full_name, FormFullName
    attribute :email, String
    attribute :phone, String
    attribute :ssn, String
  end
end

class FormProfiles::VA21686c < FormProfile
  attribute :veteran_information, VA21686c::FormContactInformation

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end

  def prefill(user)
    return {} unless user.authorize :evss, :access?
    res = EVSS::Dependents::Service.new(user).retrieve
    veteran = res.body['submitProcess']['veteran']
    VA21686c::FormContactInformation.new(
      mailing_address: prefill_address(veteran['address']),
      full_name: {
        first: veteran['firstName'],
        last: veteran['lastName'],
        middle: veteran['middleName']
      },
      email: veteran['emailAddress'],
      phone: [veteran.dig('primaryPhone', 'areaNbr'), veteran.dig('primaryPhone', 'phoneNbr')].compact.join('-'),
      ssn: veteran['ssn']
    )
  end

  private

  def prefill_address(address)
    if address['addressLine3'].present?
      address['addressLine1'] = [address['addressLine1'], address['addressLine2']].join(', ')
      address['addressLine2'] = address.delete('addressLine3')
    end

    {
      street: address['addressLine1'],
      street2: address['addressLine2'],
      city: address['city'],
      state: address['state'],
      country: address['country']['dropDownCountry'], # TODO: `"country"=>{"dropDownCountry"=>"US", "textCountry"=>""}` in the example I used
      postal_code: address['zipCode']
    }.compact
  end
end
