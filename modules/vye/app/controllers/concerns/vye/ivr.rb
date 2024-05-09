# frozen_string_literal: true

module Vye
  module Ivr
    extend ActiveSupport::Concern

    included do
      skip_before_action :authenticate, if: -> { api_key? }

      extend Common
      include Common
      include InstanceMethods
    end
  end
end
