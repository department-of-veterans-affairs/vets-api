# frozen_string_literal: true

module BGS
  class Job
    def in_progress_form_copy(in_progress_form)
      return nil if in_progress_form.blank?

      OpenStruct.new(meta_data: in_progress_form.metadata, form_data: in_progress_form.form_data)
    end

    def salvage_save_in_progress_form(form_id, user_uuid, copy)
      return if copy.blank?

      form = InProgressForm.where(form_id: form_id, user_uuid: user_uuid).first_or_initialize
      form.update(form_data: copy.form_data)
    end

    def downtime_checks
      [{ service_name: 'BDN', extra_delay: 0 }]
    end
  end
end
