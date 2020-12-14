# frozen_string_literal: true

class DirectoryApplication < ApplicationRecord
  # TODO: :BRADEN:
  # Creating a migration for this causes a weird issue. Debug on monday!
  validates :name, uniqueness: true
  validates :logo_url, :app_type, :service_categories, :platforms,
            :app_url, :description, :privacy_url, :tos_url, presence: true
end
