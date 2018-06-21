# frozen_string_literal: true

module AppealsApi
  class ApplicationController < ::OpenidApplicationController
    skip_before_action :set_tags_and_extra_context
  end
end
