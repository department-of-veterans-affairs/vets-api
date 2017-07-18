class RenameDisabilityClaimEVSSClaim < ActiveRecord::Migration
  def self.up
    rename_table :disability_claims, :evss_claims
  end

  def self.down
    rename_table :evss_claims, :disability_claims
  end
end
