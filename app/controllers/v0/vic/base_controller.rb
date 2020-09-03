# frozen_string_literal: true

module V0
  module VIC
    class BaseController < ApplicationController
      before_action :tag_sentry

      def tag_sentry
        ::VIC::TagSentry.tag_sentry
      end
    end
  end
end
