# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
# BEGIN Monkeypatch Rails 4.2 to allow for localhost to work with cookies.
if ARGV.first == 's' || ARGV.first == 'server'
  require 'rails/commands/server'

  module Rails
    class Server
      alias default_options_bk default_options
      def default_options
        default_options_bk.merge!(Host: '127.0.0.1')
      end
    end
  end
end
# END Monkeypatch Rails 4.2 to allow for localhost to work with cookies.
