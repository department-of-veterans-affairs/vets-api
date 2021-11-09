# frozen_string_literal: true

require 'dgi/configuration'
require 'common/client/base'

module MebApi
  module DGI
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      def initialize(user)
        @user = user
      end
    end
  end
end
