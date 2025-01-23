# frozen_string_literal: true

require 'evss/dependents/retrieved_info'
require 'evss/dependents/service'

module EVSS
  class DependentsApplicationJob
    include Sidekiq::Job

    sidekiq_options retry: false

    def perform(app_id, encrypted_form, user_uuid)
      @app_id = app_id
      form = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_form))
      user = User.find(user_uuid)
      service = Dependents::Service.new(user)
      cached_info = Dependents::RetrievedInfo.for_user(user)

      merged_form = DependentsApplication.transform_form(form, cached_info.body)
      merged_form = service.clean_form(merged_form)

      service.validate(merged_form).tap do |res|
        return dependents_application.update!(state: 'failed', response: res.to_json) if res['errors'].present?
      end

      form_id = service.save(merged_form)['formId']
      res = service.submit(merged_form, form_id)

      cached_info.delete

      dependents_application.update!(state: 'success', response: res.to_json)
    rescue
      dependents_application.update!(state: 'failed')
      raise
    end

    def dependents_application
      @dependents_application ||= DependentsApplication.find(@app_id)
    end
  end
end
