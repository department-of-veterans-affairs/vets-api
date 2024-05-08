# frozen_string_literal: true

module Pension21p527ez
  module TagSentry
    module_function

    TAG_NAME = 'pension_21p527ez'

    def tag_sentry
      Sentry.set_tags(feature: TAG_NAME)
    end
  end
end
