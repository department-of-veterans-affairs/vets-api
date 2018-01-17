# frozen_string_literal: true

module AppInfo
  GIT_REVISION = `git rev-parse HEAD`&.chomp
end
