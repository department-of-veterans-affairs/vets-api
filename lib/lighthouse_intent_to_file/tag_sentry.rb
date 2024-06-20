# frozen_string_literal: true

module LighthouseIntentToFile
  module TagSentry
    module_function

    TAG_NAME = 'lighthouse_intent_to_file'

    def tag_sentry
      Sentry.set_tags(feature: TAG_NAME)
    end
  end
end
