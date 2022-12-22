# frozen_string_literal: true

ClamScan.configure do |clam_config|
  clam_config.client_location = Rails.root.join('config', 'clamd.conf').to_s
  clam_config.default_scan_options = { stdout: false }
end
