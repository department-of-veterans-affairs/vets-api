# frozen_string_literal: true

module VeteranApi
  class ApplicationController < ::OpenidApplicationController
    skip_before_action :set_tags_and_extra_content, raise: false
    skip_before_action :authenticate
  end
end
