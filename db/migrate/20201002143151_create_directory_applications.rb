class CreateDirectoryApplications < ActiveRecord::Migration[6.0]
  def change
    create_table :directory_applications do |t|
      t.string :name
      t.string :logo_url
      t.text :permissions, array: true, default:[]
      t.string :type
      t.text :service_cattegories, array: true, default: []
      t.text :platforms, array: true, default: []
      t.string :app_url
      t.text :description
      t.string :privacy_url
      t.string :tos_url

      t.timestamps
    end
  end
end
