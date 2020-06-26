# frozen_string_literal: true

module VBADocuments
  class ApplicationController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action :set_tags_and_extra_context, raise: false
  end
end
