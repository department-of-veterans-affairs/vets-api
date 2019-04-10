class AddRequestedDecisionToDisabilityClaim < ActiveRecord::Migration[4.2]
  def change
    add_column :disability_claims, :requested_decision, :boolean, null: false, default: false
  end
end
