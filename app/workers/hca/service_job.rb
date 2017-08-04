module HCA
  class ServiceJob
    include Sidekiq::Worker

    def perform(user_uuid, form)
      user = User.find(user_uuid)
      HCA::Service.new(user).submit_form(form)
    end
  end
end
