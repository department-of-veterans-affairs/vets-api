# frozen_string_literal: true
module LOA
  # LOA stands for Level of Assurance
  ONE   = 'loa1'
  TWO   = 'loa2'
  THREE = 'loa3'

  MAPPING = {
    'authentication': ONE,
    'http://idmanagement.gov/ns/assurance/loa/1': ONE,
    'http://idmanagement.gov/ns/assurance/loa/2': TWO,
    'http://idmanagement.gov/ns/assurance/loa/3': THREE
  }.freeze
end
