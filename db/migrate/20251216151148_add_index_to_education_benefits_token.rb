# frozen_string_literal: true

class AddIndexToEducationBenefitsToken < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :education_benefits_claims, :token, algorithm: :concurrently, if_not_exists: true, unique: true
  end
end
