# frozen_string_literal: true

module Headers
  extend ActiveSupport::Concern

  included { prepend_before_action :set_app_info_headers }

  def set_app_info_headers
    headers['X-Git-SHA'] = AppInfo::GIT_REVISION
    headers['X-GitHub-Repository'] = AppInfo::GITHUB_URL
    headers['Timing-Allow-Origin'] = Settings.web_origin # DataDog RUM
  end
end
