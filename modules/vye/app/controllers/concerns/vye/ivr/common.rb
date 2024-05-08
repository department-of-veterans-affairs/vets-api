# frozen_string_literal: true

module Vye
  module Ivr
    module Common
      private

      def api_key_actual
        Vye
          .settings
          &.ivr_key
          &.freeze
      end
    end
  end
end
