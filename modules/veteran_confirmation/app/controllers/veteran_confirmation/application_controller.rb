# frozen_string_literal: true

module VeteranConfirmation
  class ApplicationController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action :authenticate

    def set_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'veteran_confirmation' }
      Raven.tags_context(source: 'veteran_confirmation')
    end
  end
end
