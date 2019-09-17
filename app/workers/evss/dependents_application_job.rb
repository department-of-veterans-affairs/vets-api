# frozen_string_literal: true

module EVSS
  class DependentsApplicationJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    # rubocop:disable Metrics/MethodLength
    def perform(app_id, form, user_uuid)
      @app_id = app_id
      user = User.find(user_uuid)
      service = Dependents::Service.new(user)
      cached_info = Dependents::RetrievedInfo.for_user(user)

      merged_form = DependentsApplication.transform_form(form, cached_info.body)
      merged_form = service.clean_form(merged_form)

      service.validate(merged_form).tap do |res|
        if res['errors'].present?
          return dependents_application.update!(
            state: 'failed',
            response: res.to_json
          )
        end
      end

      form_id = service.save(merged_form)['formId']
      res = service.submit(merged_form, form_id)

      cached_info.delete

      dependents_application.update!(
        state: 'success',
        response: res.to_json
      )
    rescue
      dependents_application.update!(
        state: 'failed'
      )
      raise
    end
    # rubocop:enable Metrics/MethodLength

    def dependents_application
      @dependents_application ||= DependentsApplication.find(@app_id)
    end
  end
end
