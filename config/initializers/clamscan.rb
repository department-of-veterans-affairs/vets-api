# frozen_string_literal: true
ClamScan.configure do |clam_config|
  clam_config.client_location = `which clamdscan`.strip
end
