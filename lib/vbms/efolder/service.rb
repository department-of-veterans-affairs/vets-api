# frozen_string_literal: true
module VBMS
  module Efolder
    class Service < Common::Client::Base
      STATSD_KEY_PREFIX = 'api.vbms.efolder'
      include Common::Client::Monitoring
      configuration VBMS::Efolder::Configuration

      private

      def client
        @client ||= VBMS::Client.from_env_vars(env_name: Settings.vbms.env)
      end

      # statsd helper methods - call increment_success(:foo) from a subclass. ie. Calling this method
      # from VBMS::Efolder::UploadService would increment the key: #{STATSD_KEY_PREFIX}.upload_service.foo.success
      def increment_success(*keys)
        keys.each do |key|
          StatsD.increment("#{STATSD_KEY_PREFIX}.#{self.class.name.demodulize.to_s.underscore}.#{key}.success")
        end
      end
      
      def increment_fail(*keys)
        keys.each do |key|
          StatsD.increment("#{STATSD_KEY_PREFIX}.#{self.class.name.demodulize.to_s.underscore}.#{key}.fail")
        end
      end
    end
  end
end
