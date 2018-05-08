class AddListDataToDisabilityClaim < ActiveRecord::Migration
  safety_assured

  def change
    add_column :disability_claims, :list_data, :json, null: false, default: {}
  end
end
