module AppInfo
  #TODO: figure out where revision info is stored based on deployment
  if Rails.env.production?
    GIT_REVISION = "unknown"
  else
    GIT_REVISION = `git rev-parse HEAD`.chomp
  end
end