class MakeSavedClaimIdNullableOnSubmissions < ActiveRecord::Migration[7.2]
  def up
    change_column_null :bpds_submissions, :saved_claim_id, true
    Bpds::Submission.where(saved_claim_id: 0).update_all(saved_claim_id: nil)

    change_column_null :lighthouse_submissions, :saved_claim_id, true
    Lighthouse::Submission.where(saved_claim_id: 0).update_all(saved_claim_id: nil)
  end

  def down
    Bpds::Submission.where(saved_claim_id: nil).update_all(saved_claim_id: 0)
    change_column_null :bpds_submissions, :saved_claim_id, false
    
    Lighthouse::Submission.where(saved_claim_id: nil).update_all(saved_claim_id: 0)
    change_column_null :lighthouse_submissions, :saved_claim_id, false
  end
end
