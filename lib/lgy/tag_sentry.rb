# frozen_string_literal: true

module LGY
  module TagSentry
    module_function

    def tag_sentry
      Raven.tags_context(feature: 'lgy')
    end
  end
end
