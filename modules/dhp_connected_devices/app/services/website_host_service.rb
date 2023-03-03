# frozen_string_literal: true

class WebsiteHostService
  def get_redirect_url(data)
    vendor = data.fetch(:vendor)
    status = data.fetch(:status)
    "#{WEBSITE_HOSTS[env]}/health-care/connected-devices/?#{vendor}=#{status}#_=_"
  end

  private

  WEBSITE_HOSTS = {
    'localhost' => 'http://localhost:3001',
    'test' => 'http://localhost:3001',
    'development' => 'https://dev.va.gov',
    'sandbox' => 'https://dev.va.gov',
    'staging' => 'https://staging.va.gov',
    'production' => 'https://www.va.gov'
  }.freeze

  def env
    Settings.vsp_environment
  end
end
