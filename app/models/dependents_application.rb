# frozen_string_literal: true

require 'string_helpers'

class DependentsApplication < Common::RedisStore
  include RedisForm

  validates(:user, presence: true, unless: :persisted?)
  validate(:user_can_access_evss, unless: :persisted?)

  FORM_ID = '21-686C'
  SEPARATION_TYPES = {
    'Death' => 'DEATH',
    'Divorce' => 'DIVORCED',
    'Other' => 'OTHER'
  }.freeze
  MILITARY_STATES = %w[AA AE AP].freeze

  def self.filter_children(dependents, evss_children)
    return [] if evss_children.blank? || dependents.blank?

    evss_children.find_all do |child|
      ssn = child['ssn'].delete('-')

      dependents.find do |dependent|
        dependent['childSocialSecurityNumber'] == ssn
      end
    end
  end

  def self.convert_evss_date(date)
    Date.parse(date).to_time(:utc).iso8601
  end

  def self.convert_name(full_name)
    full_name ||= {}
    full_name.transform_keys { |k| "#{k}Name" }
  end

  def self.convert_ssn(ssn)
    return {} if ssn.blank?

    {
      'ssn' => StringHelpers.hyphenated_ssn(ssn),
      'hasNoSsn' => false,
      'noSsnReasonType' => nil
    }
  end

  def self.get_address_locality(address)
    if address['country'] == 'USA'
      MILITARY_STATES.include?(address['state']) ? 'MILITARY' : 'DOMESTIC'
    else
      'INTERNATIONAL'
    end
  end

  def self.convert_address(address)
    converted = {}
    return converted if address.blank?

    converted['address'] = {
      'addressLine1' => address['street'],
      'addressLine2' => address['street2'],
      'addressLine3' => address['street3'],
      'addressLocality' => get_address_locality(address),
      'city' => address['city'],
      'country' => convert_country(address),
      'postOffice' => address['postOffice'],
      'postalType' => address['postalType'],
      'state' => address['state'],
      'zipCode' => address['postalCode']
    }

    converted
  end

  def self.convert_country(location)
    return {} if location.blank?

    {
      'dropDownCountry' => location['countryDropdown'],
      'textCountry' => location['countryText']
    }
  end

  def self.convert_previous_marriages(previous_marriages)
    return [] if previous_marriages.blank?

    previous_marriages.map do |previous_marriage|
      location_separation = previous_marriage['locationOfSeparation'] || {}

      {
        'marriageDate' => convert_evss_date(previous_marriage['dateOfMarriage']),
        'endCity' => location_separation['city'],
        'city' => previous_marriage['locationOfMarriage']['city'],
        'endCountry' => convert_country(location_separation),
        'country' => convert_country(previous_marriage['locationOfMarriage']),
        'terminatedDate' => convert_evss_date(previous_marriage['dateOfSeparation']),
        'marriageTerminationReasonType' => SEPARATION_TYPES[previous_marriage['reasonForSeparation']],
        'explainTermination' => previous_marriage['explainSeparation'],
        'endState' => location_separation['state'],
        'state' => previous_marriage['locationOfMarriage']['state']
      }.merge(
        convert_name(previous_marriage['spouseFullName'])
      )
    end
  end

  def self.convert_marriage(current_marriage, last_marriage, spouse_marriages)
    converted = {}
    return converted if current_marriage.blank?

    converted.merge!(convert_address(current_marriage['spouseAddress']))
    converted.merge!(convert_name(last_marriage['spouseFullName']))
    converted.merge!(convert_no_ssn(current_marriage['spouseHasNoSsn'], current_marriage['spouseHasNoSsnReason']))
    converted.merge!(convert_ssn(current_marriage['spouseSocialSecurityNumber']))

    converted['dateOfBirth'] = convert_evss_date(current_marriage['spouseDateOfBirth'])

    converted['currentMarriage'] = {
      'marriageDate' => convert_evss_date(last_marriage['dateOfMarriage']),
      'city' => last_marriage['locationOfMarriage']['city'],
      'country' => convert_country(last_marriage['locationOfMarriage']),
      'state' => last_marriage['locationOfMarriage']['state']
    }

    converted['vaFileNumber'] = convert_ssn(current_marriage['spouseVaFileNumber'])['ssn']
    converted['veteran'] = current_marriage['spouseIsVeteran']
    converted['previousMarriages'] = convert_previous_marriages(spouse_marriages)

    converted
  end

  def self.convert_no_ssn(no_ssn, reason_type)
    {
      'hasNoSsn' => no_ssn,
      'noSsnReasonType' => reason_type
    }
  end

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def self.set_child_attrs!(dependent, home_address, child = {})
    child.merge!(convert_name(dependent['fullName']))

    if dependent['childInHousehold']
      child.merge!(home_address)
    else
      child.merge!(convert_address(dependent['childAddress']))
    end

    dependent['childPlaceOfBirth'].tap do |place_of_birth|
      next if place_of_birth.blank?

      child['countryOfBirth'] = convert_country(place_of_birth)
      child['cityOfBirth'] = place_of_birth['city']
      child['stateOfBirth'] = place_of_birth['state']
    end

    (dependent['personWhoLivesWithChild'] || {}).tap do |guardian|
      child['guardianFirstName'] = guardian['first']
      child['guardianMiddleName'] = guardian['middle']
      child['guardianLastName'] = guardian['last']
    end

    child.merge!(convert_no_ssn(dependent['childHasNoSsn'], dependent['childHasNoSsnReason']))
    child.merge!(convert_ssn(dependent['childSocialSecurityNumber']))
    child['childRelationshipType'] = dependent['childRelationship']&.upcase

    [
      %w[attendedSchool attendingCollege],
      %w[disabled disabled],
      %w[married previouslyMarried]
    ].each do |attrs|
      val = dependent[attrs[1]]
      next if val.nil?

      child[attrs[0]] = val
    end

    [
      %w[dateOfBirth childDateOfBirth],
      %w[marriedDate marriedDate]
    ].each do |attrs|
      val = dependent[attrs[1]]
      next if val.blank?

      child[attrs[0]] = convert_evss_date(val)
    end

    child
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/MethodLength
  def self.transform_form(parsed_form, evss_form)
    dependents = parsed_form['dependents'] || []
    transformed = {}

    transformed['spouse'] = convert_marriage(
      parsed_form['currentMarriage'],
      parsed_form['marriages']&.last,
      parsed_form['spouseMarriages']
    )
    home_address = evss_form['submitProcess']['veteran'].slice('address')
    transformed['spouse'].merge!(home_address) if parsed_form['currentMarriage'].try(:[], 'liveWithSpouse')

    children = filter_children(
      dependents,
      evss_form['submitProcess']['veteran']['children']
    )

    parsed_form['dependents'].each do |dependent|
      child = children.find do |c|
        c['ssn'] == dependent['childSocialSecurityNumber']
      end

      if child
        set_child_attrs!(dependent, home_address, child)
      else
        children << set_child_attrs!(dependent, home_address)
      end
    end
    transformed['children'] = children

    transformed['marriageType'] = parsed_form['maritalStatus']

    transformed['previousMarriages'] = convert_previous_marriages(
      separate_previous_marriages(parsed_form['marriages'])
    )

    evss_form['submitProcess']['veteran'].merge!(transformed)

    Common::HashHelpers.deep_compact(evss_form)
  end
  # rubocop:enable Metrics/MethodLength

  def self.separate_previous_marriages(marriages)
    marriages&.find_all do |marriage|
      marriage['dateOfSeparation'].present?
    end
  end

  private

  def user_can_access_evss
    errors[:user] << 'must have evss access' unless user.authorize(:evss, :access?)
  end

  def create_submission_job
    EVSS::DependentsApplicationJob.perform_async(id, parsed_form, user.uuid)
  end
end
