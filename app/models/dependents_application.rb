# frozen_string_literal: true

class DependentsApplication < Common::RedisStore
  include RedisForm

  validates(:user, presence: true, unless: :persisted?)
  validate(:user_can_access_evss, unless: :persisted?)

  FORM_ID = '21-686C'

  def self.filter_children(dependents, evss_children)
    return [] if evss_children.blank? || dependents.blank?

    evss_children.find_all do |child|
      ssn = child['ssn'].gsub('-', '')

      dependents.find do |dependent|
        dependent['childSocialSecurityNumber'] == ssn
      end
    end
  end

  def self.set_child_attrs!(dependent, child = {})
    dependent['fullName'].tap do |full_name|
      next if full_name.blank?
      %w[first middle last].each do |type|
        child["#{type}Name"] = full_name[type] if full_name[type].present?
      end
    end

    dependent['childDateOfBirth'].tap do |dob|
      next if dob.blank?

      child['dateOfBirth'] = Date.parse(dob).to_time(:utc).iso8601
    end

    dependent['childAddress'].tap do |address|
      next if address.blank?

      child['address'] = {
        'addressLine1' => address['street'],
        'addressLine2' => address['street2'],
        'addressLocality' => address['addressType'],
        'city' => address['city'],
        'country' => {
          'dropDownCountry' => address['country']
        },
        'state' => address['state'],
        'zipCode' => address['postalCode']
      }
    end

    dependent['childPlaceOfBirth'].tap do |place_of_birth|
      next if place_of_birth.blank?

      place_of_birth['childCountryOfBirthDropdown'].tap do |country|
        next if country.blank?
        child['countryOfBirth'] = {
          'dropDownCountry' => country
        }
      end

      child['cityOfBirth'] = place_of_birth['childCityOfBirth'] if place_of_birth['childCityOfBirth'].present?
      child['stateOfBirth'] = place_of_birth['childStateOfBirth'] if place_of_birth['childStateOfBirth'].present?
    end

    dependent['childSocialSecurityNumber'].tap do |ssn|
      next if ssn.blank?

      child['ssn'] = StringHelpers.hyphenated_ssn(ssn)
    end

    [
      ['attendedSchool', 'attendingCollege'],
      ['disabled', 'disabled'],
      ['married', 'married']
    ].each do |attrs|
      val = dependent[attrs[1]]
      next if val.nil?
      child[attrs[0]] = val
    end

    child
  end

  def self.transform_form(parsed_form, evss_form)
    dependents = parsed_form['dependents'] || []

    children = filter_children(
      dependents,
      evss_form['submitProcess']['veteran']['children']
    )

    parsed_form['dependents'].each do |dependent|
      child = children.find do |c|
        c['ssn'] == dependent['childSocialSecurityNumber']
      end

      if child
        set_child_attrs!(dependent, child)
      else
        children << set_child_attrs!(dependent)
      end
    end

    evss_form['submitProcess']['veteran']['children'] = children

    evss_form
  end

  private

  def user_can_access_evss
    errors[:user] << 'must have evss access' unless user.authorize(:evss, :access?)
  end

  def create_submission_job
    # TODO
  end
end
