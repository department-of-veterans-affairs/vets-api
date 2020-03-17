# frozen_string_literal: true

module Common
  module VirusScan
    module_function

    def scan(file_path)
      # `clamd` runs within service group, needs group read
      File.chmod(0o640, file_path)

      # clamscan != clamdscan. clamdscan is run during prod and does not take
      # the `--config` option. If run via docker (e.g. dev, test, etc), then
      # clamscan is used, so we need to pass the db path. The binary is chosen
      # in docker-compose.yml files.
      args = if Settings.binaries.clamdscan == 'clamdscan'
               ['--config', Rails.root.join('config', 'clamd.conf').to_s]
             else
               ['--database=/srv/vets-api/clamav/database']
             end
      ClamScan::Client.scan(location: file_path, custom_args: args)
    end
  end
end
