# frozen_string_literal: true

class IvcChampvaForm < ApplicationRecord
  validates :email, presence: true, uniqueness: true

  # Add more complex data modeling here outside of CRUD
end
