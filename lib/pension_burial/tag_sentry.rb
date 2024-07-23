# frozen_string_literal: true

module PensionBurial
  module TagSentry
    module_function

    def tag_sentry
      Sentry.set_tags(feature: 'pension_burial')
    end
  end
end
