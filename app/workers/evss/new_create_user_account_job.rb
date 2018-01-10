# frozen_string_literal: true
module EVSS
  class NewCreateUserAccountJob
    include Sidekiq::Worker

    def perform(user)
      # TODO
    end
  end
end
