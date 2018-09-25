# frozen_string_literal: true

module VeteranVerification
  class ApplicationController < ::ApplicationController
    skip_before_action :set_tags_and_extra_content
  end
end
