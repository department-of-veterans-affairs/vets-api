# frozen_string_literal: true

module CentralMail
  class SubmitForm4142Job
    include Sidekiq::Worker
    def perform(user_uuid, form_content, claim_id, saved_claim_created_at); end
  end
end
