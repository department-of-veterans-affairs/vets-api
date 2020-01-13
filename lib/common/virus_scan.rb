# frozen_string_literal: true

module Common
  module VirusScan
    module_function

    def scan(file_path)
      # `clamd` runs within service group, needs group read
      File.chmod(0o640, file_path)
      args = ['--config', Rails.root.join('config', 'clamd.conf').to_s]
      ClamScan::Client.scan(location: file_path, custom_args: args)
    end
  end
end
