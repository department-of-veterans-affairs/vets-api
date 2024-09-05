class RemoveIcnFromVeteranOnboardings < ActiveRecord::Migration[7.1]
  def change
    # this table is not currently in use, so there is no concern with table locking
    safety_assured { remove_column :veteran_onboardings, :icn, :string }
  end
end
