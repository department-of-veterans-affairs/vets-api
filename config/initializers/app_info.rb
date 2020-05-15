# frozen_string_literal: true

module AppInfo
  GIT_REVISION = Env.fetch('GIT_REVISION', 'ABC1234')
  GITHUB_URL   = 'https://github.com/department-of-veterans-affairs/vets-api'
end
