# frozen_string_literal: true

module Headers
  extend ActiveSupport::Concern

  included { prepend_before_action :block_unknown_hosts, :set_app_info_headers }

  # returns a Bad Request if the incoming host header is unsafe.
  def block_unknown_hosts
    return if controller_name == 'example'
    raise Common::Exceptions::NotASafeHostError, request.host unless Settings.virtual_hosts.include?(request.host)
  end

  def set_app_info_headers
    headers['X-Git-SHA'] = AppInfo::GIT_REVISION
    headers['X-GitHub-Repository'] = AppInfo::GITHUB_URL
  end
end
