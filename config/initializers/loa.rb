# frozen_string_literal: true

module LOA
  # LOA stands for Level of Assurance
  ONE   = 1
  TWO   = 2
  THREE = 3

  MAPPING = {
    'http://idmanagement.gov/ns/assurance/loa/1/vets': ONE,
    'http://idmanagement.gov/ns/assurance/loa/2/vets': TWO,
    'http://idmanagement.gov/ns/assurance/loa/3/vets': THREE
  }.with_indifferent_access.freeze
end
