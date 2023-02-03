# frozen_string_literal: true

ClamScan.configure do |clam_config|
  clam_config.client_location = 'http://localhost:3310'
  clam_config.default_scan_options = { stdout: false }
end
