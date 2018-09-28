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

  def self.transform_form(parsed_form, evss_form)
    dependents = parsed_form['dependents'] || []

    evss_form['submitProcess']['veteran']['children'] = filter_children(
      dependents,
      evss_form['submitProcess']['veteran']['children']
    )

    parsed_form['dependents'].map do |dependent|
      child = {}

      dependent['fullName'].tap do |full_name|
        next if full_name.blank?
        child['firstName'] = full_name['first']
        child['middleName'] = full_name['middle']
        child['lastName'] = full_name['last']
      end

      child parsed_form['childDateOfBirth']  = evss_form

      child
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
