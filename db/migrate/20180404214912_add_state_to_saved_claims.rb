class AddStateToSavedClaims < ActiveRecord::Migration
  def change
    create_table "central_mail_submissions" do |t|
      t.string("state", default: "pending", null: false)
      t.references(:saved_claim, index: true, null: false)
    end
  end
end
