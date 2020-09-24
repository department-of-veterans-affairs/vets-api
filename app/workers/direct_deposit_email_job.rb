# frozen_string_literal: true

class DirectDepositEmailJob
  include Sidekiq::Worker
  sidekiq_options expires_in: 1.day

  def perform(email, ga_client_id)
    DirectDepositMailer.build(email, ga_client_id).deliver_now
  end
end
