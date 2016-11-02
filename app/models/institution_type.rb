# frozen_string_literal: true

class InstitutionType < ActiveRecord::Base
  TYPES = {
    'public' => 'Public',
    'ojt' => 'On The Job Training',
    'for profit' => 'For Profit',
    'private' => 'Private',
    'flight' => 'Flight',
    'correspondence' => 'Correspondence',
    'foreign' => 'Foreign'
  }.freeze

  has_many :institutions, inverse_of: :institution_type

  validates :name, uniqueness: true, presence: true

  # humanized school type display
  def display
    InstitutionType::TYPES[name]
  end
end
