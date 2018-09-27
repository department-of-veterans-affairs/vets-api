# frozen_string_literal: true

module EVSS
  class DependentsApplicationJob
    include Sidekiq::Worker

    def perform(id, form, user_uuid)
      Sentry::TagRainbows.tag
      dependents_application = DependentsApplication.find(id)
      user = User.find(user_uuid)
      service = Dependents::Service.new(user)
      form = service.retrieve
    end
  end
end
