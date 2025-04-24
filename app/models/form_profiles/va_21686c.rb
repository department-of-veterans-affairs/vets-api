# frozen_string_literal: true

require 'evss/dependents/retrieved_info'
require 'vets/model'

module VA21686c
  class FormAddress
    include Vets::Model

    attribute :address_type, Vets::Type::ScrubbedString
    attribute :street, Vets::Type::ScrubbedString
    attribute :street2, Vets::Type::ScrubbedString
    attribute :street3, Vets::Type::ScrubbedString
    attribute :city, Vets::Type::ScrubbedString
    attribute :state, Vets::Type::ScrubbedString
    attribute :country_dropdown, Vets::Type::ScrubbedString
    attribute :postal_code, Vets::Type::ScrubbedString
    attribute :country_text, Vets::Type::ScrubbedString
    attribute :post_office, Vets::Type::ScrubbedString
    attribute :postal_type, Vets::Type::ScrubbedString
  end

  class FormFullName
    include Vets::Model

    attribute :first, Vets::Type::ScrubbedString
    attribute :middle, Vets::Type::ScrubbedString
    attribute :last, Vets::Type::ScrubbedString
  end

  class FormLocation
    include Vets::Model

    attribute :country_dropdown, Vets::Type::ScrubbedString
    attribute :country_text, Vets::Type::ScrubbedString
    attribute :city, Vets::Type::ScrubbedString
    attribute :state, Vets::Type::ScrubbedString
  end

  class FormDependent
    include Vets::Model

    attribute :full_name, VA21686c::FormFullName
    attribute :child_date_of_birth, Vets::Type::ScrubbedString
    attribute :child_in_household, Bool
    attribute :child_address, VA21686c::FormAddress
    attribute :child_social_security_number, Vets::Type::ScrubbedString
    attribute :child_has_no_ssn, Bool
    attribute :child_has_no_ssn_reason, Vets::Type::ScrubbedString
    attribute :attending_college, Bool
    attribute :disabled, Bool
    attribute :married, Bool
    attribute :place_of_birth, VA21686c::FormLocation
  end

  class FormMarriage
    include Vets::Model

    attribute :date_of_marriage, Vets::Type::ScrubbedString
    attribute :location_of_marriage, VA21686c::FormLocation
    attribute :spouse_full_name, VA21686c::FormFullName
  end

  class FormCurrentMarriage
    include Vets::Model

    attribute :spouse_social_security_number, Vets::Type::ScrubbedString
    attribute :spouse_has_no_ssn, Bool
    attribute :spouse_has_no_ssn_reason, Vets::Type::ScrubbedString
    attribute :spouse_address, VA21686c::FormAddress
    attribute :spouse_is_veteran, Bool
    attribute :live_with_spouse, Bool
    attribute :spouse_date_of_birth, Vets::Type::ScrubbedString
  end

  class FormContactInformation
    include Vets::Model

    attribute :veteran_address, VA21686c::FormAddress
    attribute :veteran_full_name, VA21686c::FormFullName
    attribute :veteran_email, Vets::Type::ScrubbedString
    attribute :day_phone, Vets::Type::ScrubbedString
    attribute :night_phone, Vets::Type::ScrubbedString
    attribute :veteran_social_security_number, Vets::Type::ScrubbedString
    attribute :current_marriage, VA21686c::FormCurrentMarriage
    attribute :spouse_marriages, VA21686c::FormMarriage, array: true
    attribute :marriages, VA21686c::FormMarriage, array: true
    attribute :dependents, VA21686c::FormDependent, array: true
    attribute :va_file_number, Vets::Type::ScrubbedString
    attribute :marital_status, Vets::Type::ScrubbedString
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

  def prefill
    if Flipper.enabled?(:remove_pciu, user)
      return {} unless user.authorize :va_profile, :access_to_v2?
    else
      return {} unless user.authorize :evss, :access?
    end

    @veteran_information = initialize_veteran_information
    super
  end

  private

  def initialize_veteran_information
    res = EVSS::Dependents::RetrievedInfo.for_user(user)
    veteran = res.body['submitProcess']['veteran']
    spouse = veteran['spouse']

    VA21686c::FormContactInformation.new(
      {
        veteran_address: prefill_address(veteran['address']),
        veteran_full_name: prefill_name(veteran),
        veteran_email: veteran['emailAddress'],
        va_file_number: detect_file_number(veteran['vaFileNumber']),
        marital_status: veteran['marriageType'],
        day_phone: convert_phone(veteran['primaryPhone']),
        night_phone: convert_phone(veteran['secondaryPhone']),
        veteran_social_security_number: convert_ssn(veteran['ssn']),
        current_marriage: prefill_current_marriage(spouse),
        spouse_marriages: spouse.try(:[], 'previousMarriages')&.map { |m| prefill_marriage(m) },
        marriages: prefill_marriages(spouse, veteran['previousMarriages']),
        dependents: prefill_dependents(veteran['children'])
      }.compact
    )
  end

  def prefill_marriages(spouse, previous_marriages)
    marriages = previous_marriages.map { |m| prefill_marriage(m) }

    if spouse.present?
      marriage = spouse['currentMarriage']

      marriages << VA21686c::FormMarriage.new(
        {
          date_of_marriage: convert_date(marriage['marriageDate']),
          location_of_marriage: prefill_location(marriage['country'], marriage['city'], marriage['state']),
          spouse_full_name: prefill_name(spouse)
        }.compact
      )
    end

    marriages
  end

  def convert_ssn(ssn)
    return unless ssn

    ssn.tr('^0-9', '')
  end

  def convert_phone(phone)
    return unless phone

    "#{phone['areaNbr']}#{phone['phoneNbr']}".tr('^0-9', '')
  end

  def prefill_current_marriage(spouse)
    return unless spouse

    VA21686c::FormCurrentMarriage.new(
      {
        spouse_social_security_number: convert_ssn(spouse['ssn']),
        spouse_has_no_ssn: spouse['hasNoSsn'],
        spouse_has_no_ssn_reason: spouse['noSsnReasonType'],
        spouse_address: prefill_address(spouse['address']),
        spouse_is_veteran: spouse['veteran'],
        live_with_spouse: spouse['sameResidency'],
        spouse_date_of_birth: convert_date(spouse['dateOfBirth'])
      }.compact
    )
  end

  def detect_file_number(file_number)
    return if file_number.nil? || file_number.match(/^\d{3}-\d{2}-\d{4}$/)

    file_number
  end

  def prefill_marriage(marriage)
    return unless marriage

    VA21686c::FormMarriage.new(
      {
        date_of_marriage: convert_date(marriage['marriageDate']),
        location_of_marriage: prefill_location(marriage['country'], marriage['city'], marriage['state']),
        spouse_full_name: prefill_name(marriage),
        reason_for_separation: marriage['marriageTerminationReasonType'],
        date_of_separation: convert_date(marriage['terminatedDate']),
        location_of_separation: prefill_location(marriage['endCountry'], marriage['endCity'], marriage['endState'])
      }.compact
    )
  end

  def prefill_location(country, city, state)
    country ||= {}
    VA21686c::FormLocation.new(
      {
        country_dropdown: country['dropDownCountry'],
        country_text: country['textCountry'],
        city:,
        state:
      }.compact
    )
  end

  def convert_date(date)
    return unless date

    Time.strptime(date.to_s, '%Q').utc.to_date.to_s
  end

  def prefill_dependents(children)
    return [] if children.blank?

    children.map do |child|
      VA21686c::FormDependent.new(
        {
          full_name: prefill_name(child),
          child_date_of_birth: convert_date(child['dateOfBirth']),
          child_in_household: child['sameResidency'],
          child_address: prefill_address(child['address']),
          child_social_security_number: convert_ssn(child['ssn']),
          child_has_no_ssn: child['hasNoSsn'],
          child_has_no_ssn_reason: child['noSsnReasonType'],
          attending_college: child['attendedSchool'],
          disabled: child['disabled'],
          married: child['married'],
          child_place_of_birth: prefill_location(child['countryOfBirth'], child['cityOfBirth'], child['stateOfBirth']),
          child_relationship_type: child['childRelationshipType']
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
    return unless address

    address = VA21686c::FormAddress.new(
      {
        address_type: address['addressLocality'],
        street: address['addressLine1'],
        street2: address['addressLine2'],
        street3: address['addressLine3'],
        city: address['city'],
        state: address['state'],
        postal_code: "#{address['zipCode']}#{"-#{address['zipLastFour']}" if address['zipLastFour'].present?}",
        country_dropdown: address.dig('country', 'dropDownCountry'),
        country_text: address.dig('country', 'textCountry'),
        post_office: address['postOffice'],
        postal_type: address['postalType']
      }.compact
    )
    return if address.attributes.values.uniq.all? { |x| ['DOMESTIC', ''].include? x }

    address
  end
end
