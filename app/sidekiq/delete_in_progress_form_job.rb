# frozen_string_literal: true

class DeleteInProgressFormJob
  include Sidekiq::Job

  sidekiq_options retry: 5

  def perform(form_id, user_uuid)
    return unless user_uuid

    # Keeping this logging with the multiple find_bys to confirm this fixes an issue we were seeing.
    # After confirming we can simply delete the InProgressForm
    in_progress_form_before = InProgressForm.find_by(form_id:, user_uuid:)

    InProgressForm.find_by(form_id:, user_uuid:)&.destroy

    in_progress_form_after = InProgressForm.find_by(form_id:, user_uuid:)

    Rails.logger.info("[#{form_id}][user_uuid:#{user_uuid}]" \
                      "[ipf_id_before:#{in_progress_form_before&.id}, ipf_id_after:#{in_progress_form_after&.id}]" \
                      " - InProgressForm successfully deleted: #{in_progress_form_after.nil?}")
  end
end
