class CreateAppealSubmissions < ActiveRecord::Migration[6.0]
  def change
    create_table :appeal_submissions do |t|
      t.string :user_uuid
      t.string :submitted_appeal_uuid
      t.string :type_of_appeal
      t.string :board_review_otpion

      t.timestamps
    end
  end
end
