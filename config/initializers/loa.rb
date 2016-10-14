# frozen_string_literal: true
module LOA
  # LOA stands for Level of Assurance
  ONE   = 1
  TWO   = 2
  THREE = 3

  loa1_mapping_key = Rails.env.development? ? 'authentication' : 'http://idmanagement.gov/ns/assurance/loa/1'
  MAPPING = {
    loa1_mapping_key => ONE,
    'http://idmanagement.gov/ns/assurance/loa/2': TWO,
    'http://idmanagement.gov/ns/assurance/loa/3': THREE
  }.freeze
end
