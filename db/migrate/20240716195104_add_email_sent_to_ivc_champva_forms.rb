class AddEmailSentToIvcChampvaForms < ActiveRecord::Migration[7.1]
  def change
    add_column :ivc_champva_forms, :email_sent, :boolean, null: false, default: false
  end
end
