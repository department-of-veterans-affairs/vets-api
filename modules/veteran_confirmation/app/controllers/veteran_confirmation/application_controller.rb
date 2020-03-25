# frozen_string_literal: true

module VeteranConfirmation
  class ApplicationController < ::ApplicationController
    skip_before_action :set_tags_and_extra_context, raise: false
    skip_before_action(:authenticate)
  end
end
