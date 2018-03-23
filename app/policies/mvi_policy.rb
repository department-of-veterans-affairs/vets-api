# frozen_string_literal: true

MviPolicy = Struct.new(:user, :mvi) do
  def queryable?
    user.icn.present? || required_attrs_present?(user)
  end

  private

  def required_attrs_present?(user)
    return if user.first_name.blank?
    return if user.last_name.blank?
    return if user.birth_date.blank?
    return if user.ssn.blank?
    return if user.gender.blank?

    true
  end
end
