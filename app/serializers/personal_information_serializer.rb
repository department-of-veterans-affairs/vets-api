# frozen_string_literal: true

class PersonalInformationSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :gender do |object|
    object.demographics&.gender
  end

  # Returns the veteran's birth date.  Object is an instance
  # of the MPI::Models::MviProfile class.
  #
  # @return [String] For example, '1949-03-04'
  #
  attribute :birth_date do |object|
    object.demographics&.birth_date&.to_date&.to_s
  end

  # Returns the veteran's preferred name.
  #
  # @return [String] For example, 'SAM'
  #
  attribute :preferred_name do |object|
    object.demographics&.preferred_name&.text
  end

  # Returns the veteran's gender identity.
  #
  # @return [Object] For example, code: 'F', name: 'Female'
  #
  attribute :gender_identity do |object|
    return {} if object.demographics&.gender_identity&.nil?

    {
      code: object.demographics&.gender_identity&.code,
      name: object.demographics&.gender_identity&.name
    }
  end
end
