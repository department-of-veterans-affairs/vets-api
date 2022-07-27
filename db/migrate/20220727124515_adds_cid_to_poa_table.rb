class AddsCidToPoaTable < ActiveRecord::Migration[6.1]
  def change
    add_column :claims_api_power_of_attorneys, :cid, :string
  end
end
