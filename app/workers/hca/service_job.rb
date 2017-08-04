module HCA
  class ServiceJob
    include Sidekiq::Worker

    def perform(user_uuid, form, health_care_application_id)
      result = HCA::Service.new(User.find(user_uuid)).submit_form(form)
      Rails.logger.info "SubmissionID=#{result[:formSubmissionId]}"
    end
  end
end
