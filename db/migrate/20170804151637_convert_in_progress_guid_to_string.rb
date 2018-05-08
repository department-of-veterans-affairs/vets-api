class ConvertInProgressGuidToString < ActiveRecord::Migration
  safety_assured
  
  def up
    change_column :in_progress_forms, :user_uuid, :string, :null => false

    InProgressForm.connection.schema_cache.clear!
    InProgressForm.reset_column_information

    InProgressForm.all.each { |form|
      form.update_attribute(:user_uuid, form.user_uuid.gsub!('-', ''))
    }
  end
end
