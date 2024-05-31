# frozen_string_literal: true

module Vye
  module Ivr
    extend ActiveSupport::Concern

    included do
      extend Common
      include Common
      include InstanceMethods

      singleton_class.class_eval do
        alias_method :api_key, :api_key_actual
        undef_method :api_key_actual
        public :api_key
      end

      skip_before_action :authenticate, if: -> { api_key? }
    end
  end
end
