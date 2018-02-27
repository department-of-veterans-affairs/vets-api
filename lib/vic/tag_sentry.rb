module VIC
  module TagSentry
    module_function

    def tag_sentry
      Raven.tags_context(feature: 'vic2')
    end
  end
end
