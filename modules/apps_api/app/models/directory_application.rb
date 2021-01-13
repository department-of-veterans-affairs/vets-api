# frozen_string_literal: true

class DirectoryApplication < ApplicationRecord
  validates :name, uniqueness: true
  validates :logo_url, :app_type, :service_categories, :platforms,
            :app_url, :description, :privacy_url, :tos_url, presence: true
end
