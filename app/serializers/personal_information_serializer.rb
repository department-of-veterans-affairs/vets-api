# frozen_string_literal: true

class PersonalInformationSerializer < ActiveModel::Serializer
  attributes :gender, :birth_date, :preferred_name, :gender_identity

  delegate :gender, to: :object

  def id
    nil
  end

  def gender
    object.demographics&.gender
  end

  # Returns the veteran's birth date.  Object is an instance
  # of the MPI::Models::MviProfile class.
  #
  # @return [String] For example, '1949-03-04'
  #
  def birth_date
    object.demographics&.birth_date&.to_date&.to_s
  end

  # Returns the veteran's preferred name.
  #
  # @return [String] For example, 'SAM'
  #
  def preferred_name
    object.demographics&.preferred_name&.text
  end

  # Returns the veteran's gender identity.
  #
  # @return [Object] For example, code: 'F', name: 'Female'
  #
  def gender_identity
    return {} if object.demographics&.gender_identity&.nil?

    {
      code: object.demographics&.gender_identity&.code,
      name: object.demographics&.gender_identity&.name
    }
  end
end
