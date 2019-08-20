# frozen_string_literal: true

module ClaimsApi
  module ItfVerification
    extend ActiveSupport::Concern

    included do
      def foo
        binding.pry
      end
    end
  end
end
