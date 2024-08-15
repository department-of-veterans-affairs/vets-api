# frozen_string_literal: true

module Pensions
  module TagSentry
    module_function

    # pension specific tracing tag
    TAG_NAME = 'pension_21p527ez'

    # add feature tag for sentry tracing
    def tag_sentry
      Sentry.set_tags(feature: TAG_NAME)
    end
  end
end
