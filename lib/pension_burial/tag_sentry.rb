# frozen_string_literal: true

module PensionBurial
  module TagSentry
    module_function

    def tag_sentry
      Raven.tags_context(feature: 'pension_burial')
    end
  end
end
