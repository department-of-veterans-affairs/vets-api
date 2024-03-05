# frozen_string_literal: true

module LGY
  module TagSentry
    module_function

    def tag_sentry
      Sentry.set_tags(feature: 'lgy')
    end
  end
end
