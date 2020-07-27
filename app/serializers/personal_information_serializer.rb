# frozen_string_literal: true

class PersonalInformationSerializer < ActiveModel::Serializer
  attribute :gender
  attribute :birth_date

  delegate :gender, to: :object

  def id
    nil
  end

  # Returns the veteran's birth date.  Object is an instance
  # of the MVI::Models::MviProfile class.
  #
  # @return [String] For example, '1949-03-04'
  #
  def birth_date
    object.birth_date.to_date.to_s
  end
end
