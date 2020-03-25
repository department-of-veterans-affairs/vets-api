class AddVisnToBaseFacilities < ActiveRecord::Migration[5.2]
  def change
    add_column :base_facilities, :visn, :string
  end
end
