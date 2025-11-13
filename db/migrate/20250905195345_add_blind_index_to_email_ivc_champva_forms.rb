class AddBlindIndexToEmailIvcChampvaForms < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :ivc_champva_forms, :email_bidx, algorithm: :concurrently, if_not_exists: true
  end
end
  