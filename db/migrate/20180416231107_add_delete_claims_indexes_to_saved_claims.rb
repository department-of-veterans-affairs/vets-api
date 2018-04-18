class AddDeleteClaimsIndexesToSavedClaims < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:saved_claims, [:created_at, :type], algorithm: :concurrently)
    add_index(:central_mail_submissions, :state, algorithm: :concurrently)
  end
end
