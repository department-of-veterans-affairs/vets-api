# frozen_string_literal: true

class CreateDirectoryApplications < ActiveRecord::Migration[6.0]
  def change
    create_table :directory_applications do |t|
      t.string :name
      t.string :logo_url
      t.string :app_type
      t.text :service_categories, array: true, default: []
      t.text :platforms, array: true, default: []
      t.string :app_url
      t.text :description
      t.string :privacy_url
      t.string :tos_url

      t.timestamps
    end
  end
end
