if defined?(ENV['VSP_ENVIRONMENT']) && ENV['VSP_ENVIRONMENT'] == "development"
  Settings.add_source!("#{Rails.root}/config/settings/#{ENV['VSP_ENVIRONMENT']}.local.yml")
  Settings.reload!
end
