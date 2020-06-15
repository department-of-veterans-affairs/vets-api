# frozen_string_literal: true

class Form526ConfirmationEmailJob
  include Sidekiq::Worker
  sidekiq_options expires_in: 1.day

  def perform(id, email="")
    # send email
  end
end
