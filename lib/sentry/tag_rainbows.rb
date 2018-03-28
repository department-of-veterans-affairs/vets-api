# frozen_string_literal: true

module Sentry
  module TagRainbows
    module_function

    def tag
      Raven.tags_context(team: 'rainbows')
    end
  end
end
