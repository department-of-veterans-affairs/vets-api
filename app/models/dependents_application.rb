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

  def self.hyphenate_ssn(ssn)
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
        'city' => address['city'],
        'country' => {
          'dropDownCountry' => address['country']
        },
        'state' => address['state'],
        'zipCode' => address['postalCode']
      }
    end

    child['countryOfBirth'] ||= {}
    child['countryOfBirth']['dropDownCountry'] = dependent['childPlaceOfBirth'] if dependent['childPlaceOfBirth'].present?

    child['ssn'] = dependent['childSocialSecurityNumber']
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
  end

  private

  def user_can_access_evss
    errors[:user] << 'must have evss access' unless user.authorize(:evss, :access?)
  end

  def create_submission_job
    # TODO
  end
end
