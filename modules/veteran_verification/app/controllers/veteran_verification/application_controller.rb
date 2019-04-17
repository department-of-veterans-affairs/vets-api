# frozen_string_literal: true

module VeteranVerification
  class ApplicationController < ::OpenidApplicationController
    skip_before_action :set_tags_and_extra_content, raise: false
  end
end
