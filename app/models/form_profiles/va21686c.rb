# frozen_string_literal: true

module VA21686c
  class FormAddress
    include Virtus.model

    attribute :address_locality, String
    attribute :street, String
    attribute :street2, String
    attribute :street3, String
    attribute :city, String
    attribute :state, String
    attribute :country, String
    attribute :postal_code, String
    attribute :country_dropdown, String
    attribute :country_test, String
    attribute :post_office, String
    attribute :postal_type, String
    attribute :shared_address_ind, String
  end

  class FormFullName
    include Virtus.model

    attribute :first, String
    attribute :middle, String
    attribute :last, String
  end

  class FormPlaceOfBirth
    include Virtus.model

    attribute :child_country_of_birth_dropdown, String
    attribute :child_country_of_birth_text, String
    attribute :child_city_of_birth, String
    attribute :child_state_of_birth, String
  end

  class FormDependent
    include Virtus.model

    attribute :full_name, VA21686c::FormFullName
    attribute :child_date_of_birth, String
    attribute :child_in_household, Boolean
    attribute :child_address, VA21686c::FormAddress
    attribute :child_social_security_number, String
    attribute :attending_college, Boolean
    attribute :disabled, Boolean
    attribute :married, Boolean
    attribute :place_of_birth, VA21686c::FormPlaceOfBirth
  end

  class FormContactInformation
    include Virtus.model

    attribute :claimant_address, VA21686c::FormAddress
    attribute :claimant_full_name, VA21686c::FormFullName
    attribute :claimant_email, String
    attribute :phone, String
    attribute :ssn, String
    attribute :dependents, Array[VA21686c::FormDependent]
  end

  class FormLocation
    include Virtus.model

    attribute :country_dropdown, String
    attribute :country_text, String
    attribute :city, String
    attribute :state, String
  end

  class FormMarriage
    include Virtus.model

    attribute :date_of_marriage, String # TODO parse this?
    attribute :location_of_marriage, VA21686c::FormLocation
    attribute :spouse_full_name, VA21686c::FormFullName
    attribute :spouse_social_securty_number, String
  end
end

class FormProfiles::VA21686c < FormProfile
  # attribute :veteran_information, VA21686c::FormContactInformation # TODO: remove?

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end

  # r["submitProcess"]["veteran"]["previousMarriages"][0].keys
  # => ["city", "country", "dependentStatus", "endCity", "endCountry", "endState", "exSpouse", "firstName", "lastName", "marriageDate", "marriageTerminationReasonType", "state", "terminatedDate"]

  # r["submitProcess"]["veteran"]["spouse"]["currentMarriage"].keys
  # => ["city", "country", "dependentStatus", "endCountry", "exSpouse", "marriageDate", "marriageTerminationReasonType", "state"]

  def prefill(user)
    return {} unless user.authorize :evss, :access?
    binding.pry
    res = EVSS::Dependents::Service.new(user).retrieve
    veteran = res.body['submitProcess']['veteran']
    spouse = veteran.deep_dup.fetch('spouse') { { 'previousMarriages' => [], 'address' => {} } }
    VA21686c::FormContactInformation.new(
      veteran_address: prefill_address(veteran['address']),
      # veteran_full_name: prefill_name(veteran),
      veteran_email: veteran['emailAddress'],
      # phone: [veteran.dig('primaryPhone', 'areaNbr'), veteran.dig('primaryPhone', 'phoneNbr')].compact.join('-'),
      # ssn: veteran['ssn'],
      current_marriage: prefill_marriage(spouse.merge!(spouse.delete('currentMarriage') { {} })),
      previous_marriages: veteran['previousMarriages'].map { |m| prefill_marriage(m) },
      spouse_marriages: spouse['previousMarriages'].map { |m| prefill_marriage(m) },
      spouse_address: prefill_address(spouse),
      spouse_is_veteran: spouse['veteran'],
      live_with_spouse: spouse['sameResidency'],
      monthly_spouse_payment: nil, # TODO: I don't see this in any of my example data

      # left off here
      dependents: prefill_dependents(veteran['children'])
    )
  end

  private

  def prefill_marriage(marriage)
    return unless marriage
    VA21686c::FormMarriage.new(
      {
        date_of_marriage: convert_date(marriage['marriageDate']), # ???
        location_of_marriage: prefill_location(marriage['country'], marriage['city'], marriage['state']),
        spouse_full_name: prefill_name(marriage),
        spouse_social_securty_number: marriage['ssn'],
        reason_for_separation: marriage['marriageTerminationReasonType'],
        date_of_separation: convert_date(marriage['terminatedDate']),
        location_of_separation: prefill_location(marriage['endCountry'], marraige['endCity'], marriage['endState'])
      }.compact
    )
  end

  # place of marriage
  # place marriage terminated
  # child place of birth
  def prefill_location(country, city, state)
    return unless location
    # TODO: make this a `Form` model
    VA21686c::FormLocation.new(
      {
        country_dropdown: country['dropDownCountry'],
        country_text: country['textCountry'],
        city: city,
        state: state
      }.compact
    )
  end

  # def prefill_previous_marriage(spouse)
  #   VA21686c::FormPreviousMarriage.new(
  #     {
  #       date_of_marriage: '', # ???
  #       location_of_marriage: '', # ???
  #       spouse_full_name: prefill_name(spouse),
  #       reason_for_separatio: spouse[''],
  #     }.compact
  #   )
  # end

  def convert_date(date)
    return unless date
    Date.strptime(date.to_s, '%Q').strftime('%Y-%m-%d')
  end

  def prefill_dependents(children)
    binding.pry
    return [] if children.blank?
    children.map do |child|
      FormDependent.new(
        {
        #   full_name: prefill_name(child),
        #   child_date_of_birth: convert_date(child['dateOfBirth']),
        #   child_in_household: child['sameResidency'],
        #   child_address: prefill_address(child['address']),
        #   child_social_security_number: child['ssn'],
        #   attending_college: child['attendedSchool'],
        #   disabled: child['disabled'],
        #   married: child['married'],
        #   child_place_of_birth: FormPlaceOfBirth.new(
        #     {
        #       child_country_of_birth_dropdown: child['countryOfBirth']['dropDownCountry'],
        #       child_country_of_birth_text: child['countryOfBirth']['textCountry'],
        #       child_city_of_birth: child['cityOfBirth'],
        #       child_state_of_birth: child['stateOfBirth']
        #     }.compact
        #   )
        }.compact
      )
    end
  end

  def prefill_name(person)
    VA21686c::FormFullName.new(
      {
        first: person['firstName'],
        last: person['lastName'],
        middle: person['middleName']
      }.compact
    )
  end

  def prefill_address(address)
    VA21686c::FormAddress.new(
      {
        address_locality: address['addressLocality'],
        street: address['addressLine1'],
        street2: address['addressLine2'],
        street3: address['addressLine3'],
        city: address['city'],
        state: address['state'],
        postal_code: "#{address['zipCode']}-#{address['zipLastFour']}",
        country_dropdown: address.dig('country', 'dropDownCountry'),
        country_text: address.dig('country', 'textCountry'),
        post_office: address['postOffice'],
        postal_type: address['postalType'],
        shared_address_ind: address['sharedAddrsInd']
      }.compact
    )
  end
end
