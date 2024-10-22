# frozen_string_literal: true

require 'dgi/configuration'
require 'common/client/base'

module Vye
  module DGIB
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      def initialize(user)
        @user = user
      end
    end
  end
end
