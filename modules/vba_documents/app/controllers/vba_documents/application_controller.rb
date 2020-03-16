# frozen_string_literal: true

module VBADocuments
  class ApplicationController < ::ExternalApiApplicationController
    skip_before_action :set_tags_and_extra_context, raise: false
  end
end
