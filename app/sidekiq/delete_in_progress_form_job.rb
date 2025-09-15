# frozen_string_literal: true

class DeleteInProgressFormJob
  include Sidekiq::Job

  sidekiq_options retry: 5

  def perform(form_id, current_user)
    return unless current_user

    in_progress_form_before = InProgressForm.form_for_user(form_id, current_user)
    InProgressForm.form_for_user(form_id, current_user)&.destroy

    in_progress_form_after = InProgressForm.form_for_user(form_id, current_user)

    Rails.logger.info("[10-10EZ][user_uuid:#{current_user.uuid}]" \
                      "[ipf_id_before:#{in_progress_form_before&.id}, ipf_id_after:#{in_progress_form_after&.id}]" \
                      " - InProgressForm successfully deleted: #{in_progress_form_after.nil?}")
  end
end
