module AppInfo
  if Rails.env.development?
    GIT_REVISION = `git rev-parse HEAD`.chomp
  else
    #TODO: git SHA available once devops PR #271 is merged:
    #https://github.com/department-of-veterans-affairs/devops/pull/271
    GIT_REVISION = "unknown"
  end
end