# frozen_string_literal: true

module VetsApi
  module Commands
    class Info
      def self.run
        puts <<~INFO
          Rails version:      #{Rails.version}
          Ruby version:       #{RUBY_DESCRIPTION}
          Gem version:        #{`gem --version`.chomp}
          Bundler version:    #{`bundle --version`.chomp}
          Environment:        #{Rails.env}
          Postgres Version:   #{`postgres --version`.chomp}
          Redis version:      #{`redis-cli --version`.chomp}
          Docker:             #{`docker -v`&.chomp}
          Host OS:            #{RbConfig::CONFIG['host_os']}
        INFO
      end
    end
  end
end
