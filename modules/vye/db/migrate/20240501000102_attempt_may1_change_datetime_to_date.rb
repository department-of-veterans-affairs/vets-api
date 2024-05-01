class AttemptMay1ChangeDatetimeToDate < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :vye_awards, :award_begin_date, :datetime if column_exists?(:vye_awards, :award_begin_date)
      add_column :vye_awards, :award_begin_date, :date

      remove_column :vye_awards, :award_end_date, :datetime if column_exists?(:vye_awards, :award_end_date)
      add_column :vye_awards, :award_end_date, :date

      remove_column :vye_awards, :payment_date, :datetime if column_exists?(:vye_awards, :payment_date)
      add_column :vye_awards, :payment_date, :date

      remove_column :vye_pending_documents, :queue_date, :datetime if column_exists?(:vye_pending_documents, :queue_date)
      add_column :vye_pending_documents, :queue_date, :date
      
      remove_column :vye_user_infos, :cert_issue_date, :datetime if column_exists?(:vye_user_infos, :cert_issue_date)
      add_column :vye_user_infos, :cert_issue_date, :date

      remove_column :vye_user_infos, :del_date, :datetime if column_exists?(:vye_user_infos, :del_date)
      add_column :vye_user_infos, :del_date, :date

      remove_column :vye_user_infos, :date_last_certified, :datetime if column_exists?(:vye_user_infos, :date_last_certified)
      add_column :vye_user_infos, :date_last_certified, :date
    end
  end
end
