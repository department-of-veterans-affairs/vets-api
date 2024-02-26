# frozen_string_literal: true

module AccreditedRepresentatives
  module V0
    class ArbitraryController < ApplicationController
      def arbitrary = head :ok
    end
  end
end
