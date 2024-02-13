# frozen_string_literal: true

module SimpleFormsApi
  module V1
    class ApplicationController < ::ApplicationController
      service_tag 'veteran-facing-forms'
    end
  end
end
