# frozen_string_literal: true
module DataMigrations
  module UuidUniqueIndex
    module_function

    def run
      InProgressForm.select(:form_id, :user_uuid).group(:form_id, :user_uuid).having("count(*) > 1").each do |in_progress_form|
        InProgressForm.where(form_id: in_progress_form.form_id, user_uuid: in_progress_form.user_uuid).order('updated_at DESC').all.each_with_index do |form, i|
          next if i == 0
          form.destroy
        end
      end
    end
  end
end
