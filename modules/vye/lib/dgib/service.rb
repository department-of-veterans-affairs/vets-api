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

      def camelize_keys_for_java_service(params)
        local_params = params[0] || params

        local_params.permit!.to_h.deep_transform_keys do |key|
          if key.include?('_')
            split_keys = key.split('_')
            split_keys.collect { |key_part| split_keys[0] == key_part ? key_part : key_part.capitalize }.join
          else
            key
          end
        end
      end
    end
  end
end
