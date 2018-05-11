class AddListDataToDisabilityClaim < ActiveRecord::Migration
  def change
    safety_assured { add_column :disability_claims, :list_data, :json, null: false, default: {} }
  end
end
