# frozen_string_literal: true

module VaFacilities
  class ApplicationController < ::ApplicationController
    skip_before_action :set_tags_and_extra_context, raise: false
  end
end
