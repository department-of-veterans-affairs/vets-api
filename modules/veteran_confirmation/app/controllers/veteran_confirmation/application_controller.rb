# frozen_string_literal: true

module VeteranConfirmation
  class ApplicationController < ::ApplicationController
    service_tag 'lighthouse-veteran-confirmation'
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action :authenticate

    def set_sentry_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'veteran_confirmation' }
      Sentry.set_tags(source: 'veteran_confirmation')
    end
  end
end
