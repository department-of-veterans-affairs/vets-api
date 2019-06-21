# frozen_string_literal: true

module Vsp
  module V0
    class HelloWorldController < ApplicationController
      skip_before_action :authenticate

      def index

      end
    end
  end
end
