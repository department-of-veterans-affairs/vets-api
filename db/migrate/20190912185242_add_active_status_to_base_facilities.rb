class AddActiveStatusToBaseFacilities < ActiveRecord::Migration[5.2]
  def change
    add_column :base_facilities, :active_status, :string
  end
end
