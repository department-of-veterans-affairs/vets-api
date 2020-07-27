# frozen_string_literal: true

MviPolicy = Struct.new(:user, :mvi) do
  def queryable?
    user.icn.present? || required_attrs_present?(user)
  end

  private

  def required_attrs_present?(user)
    return false if user.first_name.blank?
    return false if user.last_name.blank?
    return false if user.birth_date.blank?
    return false if user.ssn.blank?
    return false if user.gender.blank?

    true
  end
end
