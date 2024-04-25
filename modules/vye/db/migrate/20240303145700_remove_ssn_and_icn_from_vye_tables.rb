class RemoveSsnAndIcnFromVyeTables < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_columns(
        :vye_user_infos,
        :icn,
        :ssn_ciphertext,
        :ssn_digest
      )

      remove_columns(
        :vye_pending_documents,
        :claim_no_ciphertext,
        :ssn_ciphertext,
        :ssn_digest
      )
    end
  end
end
