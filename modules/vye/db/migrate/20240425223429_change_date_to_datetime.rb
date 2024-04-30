class ChangeDateToDatetime < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      change_column :vye_awards, :award_begin_date, :datetime
      change_column :vye_awards, :award_end_date, :datetime
      change_column :vye_awards, :payment_date, :datetime

      change_column :vye_pending_documents, :queue_date, :datetime

      change_column :vye_user_infos, :cert_issue_date, :datetime
      change_column :vye_user_infos, :del_date, :datetime
      change_column :vye_user_infos, :date_last_certified, :datetime
    end
  end
end
