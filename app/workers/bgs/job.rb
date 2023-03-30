# frozen_string_literal: true

module BGS
  class Job
    def in_progress_form_copy(in_progress_form)
      return nil if in_progress_form.blank?

      OpenStruct.new(meta_data: in_progress_form.metadata,
                     form_data: in_progress_form.form_data,
                     user_account: in_progress_form.user_account)
    end

    def salvage_save_in_progress_form(form_id, user_uuid, copy)
      return if copy.blank?

      form = InProgressForm.where(form_id:, user_uuid:).first_or_initialize
      form.user_account = copy.user_account
      form.update(form_data: copy.form_data)
    end
  end
end
