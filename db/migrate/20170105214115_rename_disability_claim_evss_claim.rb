class RenameDisabilityClaimEVSSClaim < ActiveRecord::Migration[4.2]
  def self.up
    rename_table :disability_claims, :evss_claims
  end

  def self.down
    rename_table :evss_claims, :disability_claims
  end
end
