# frozen_string_literal: true

class DeleteInProgressFormJob
  include Sidekiq::Job

  sidekiq_options retry: 5

  def perform(form_id, user_uuid)
    return unless user_uuid

    InProgressForm.find_by(form_id:, user_uuid:)&.destroy
  end
end
