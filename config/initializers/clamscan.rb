# frozen_string_literal: true

ClamScan.configure do |clam_config|
  clam_config.client_location = Rails.root.join('app', 'config', 'clamd.conf')
  clam_config.default_scan_options = { stdout: false }
end
