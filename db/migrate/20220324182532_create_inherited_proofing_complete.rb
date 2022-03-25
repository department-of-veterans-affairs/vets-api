class CreateInheritedProofingComplete < ActiveRecord::Migration[6.1]
  def change
    create_table :inherited_proof_verified_user_accounts do |t|
      t.references :user_account, type: :uuid, foreign_key: :true, null: false, index: { unique: true }
      t.timestamps
    end
  end
end
