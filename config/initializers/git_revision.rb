module AppInfo
  if Rails.env.production?
    GIT_REVISION = ENV["APP_GIT_SHA"]
  else
    GIT_REVISION = `git rev-parse HEAD`.chomp
  end
end