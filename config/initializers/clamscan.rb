# frozen_string_literal: true

ClamScan.configure do |clam_config|
  File.chmod(0o640, Rails.root.to_s + '/config/clamd.conf')
  clam_config.client_location = Settings.binaries.clamdscan
  clam_config.default_scan_options = { stdout: false }
end
