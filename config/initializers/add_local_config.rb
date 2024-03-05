# frozen_string_literal: true

if defined?(ENV.fetch('VSP_ENVIRONMENT', nil))
  Settings.prepend_source!(Rails.root.join("config/settings/#{ENV.fetch('VSP_ENVIRONMENT', nil)}.local.yml").to_s)
  Settings.reload!
end
