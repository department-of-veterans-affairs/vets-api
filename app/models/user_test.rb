# frozen_string_literal: true

class UserTest < ApplicationRecord
  # Following Strong Migrations pattern - but this should NOT be in same PR as migration!
  self.ignored_columns += ['legacy_field']
  
  validates :email, presence: true
end