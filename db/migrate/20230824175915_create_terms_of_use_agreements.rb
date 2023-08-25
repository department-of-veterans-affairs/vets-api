class CreateTermsOfUseAgreements < ActiveRecord::Migration[6.1]
  def change
    create_table :terms_of_use_agreements do |t|
      t.references :user_account, null: false, foreign_key: true, type: :uuid
      t.string :agreement_version, null: false
      t.integer :response, null: false
      t.timestamps
    end
  end
end
