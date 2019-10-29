# frozen_string_literal: true

module AppInfo
  GIT_REVISION = `git rev-parse HEAD`&.chomp
  GITHUB_REPO  = 'https://github.com/department-of-veterans-affairs/vets-api'
end
