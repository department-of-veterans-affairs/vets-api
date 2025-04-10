class MakeSavedClaimIdNullableOnBpdsSubmissions < ActiveRecord::Migration[7.2]
  def change
    change_column_null :bpds_submissions, :saved_claim_id, true
  end
end
