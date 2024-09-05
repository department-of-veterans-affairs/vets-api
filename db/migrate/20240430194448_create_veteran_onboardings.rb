class CreateVeteranOnboardings < ActiveRecord::Migration[7.1]
  def change
    create_table :veteran_onboardings do |t|
      t.string :icn
      t.boolean :display_onboarding_flow, default: true

      t.timestamps
    end

    add_index :veteran_onboardings, :icn, unique: true
  end
end
