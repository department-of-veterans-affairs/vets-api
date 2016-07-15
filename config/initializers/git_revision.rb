module AppInfo
  if Rails.env.production?
    #TODO: git SHA available once devops PR #271 is merged:
    #https://github.com/department-of-veterans-affairs/devops/pull/271
    GIT_REVISION = "unknown"
  else
    GIT_REVISION = `git rev-parse HEAD`.chomp
  end
end