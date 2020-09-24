# frozen_string_literal: true

module LogMetrics
  extend ActiveSupport::Concern

  KEY_PREFIX = 'api.upload.'

  included do
    after(:store, :log_metrics)
  end

  def log_metrics(file)
    class_name = self.class.to_s.underscore
    class_prefix = "#{KEY_PREFIX}#{class_name}"

    args = [
      "#{class_prefix}.size",
      file.size
    ]

    file.content_type.tap do |content_type|
      next if content_type.blank?

      args << {
        tags: ["content_type:#{content_type.split('/')[1]}"]
      }
    end

    StatsD.measure(*args)
  end
end
