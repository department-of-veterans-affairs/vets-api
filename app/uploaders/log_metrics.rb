# frozen_string_literal: true

module LogMetrics
  extend ActiveSupport::Concern

  KEY_PREFIX = 'api.upload.'

  included do
    after(:store, :log_metrics)
  end

  def log_metrics(file)
    class_name = self.class.to_s.gsub('::', '_').underscore
    class_prefix = "#{KEY_PREFIX}#{class_name}"

    args = [
      "#{class_prefix}.size",
      file.size
    ]

    kw_args = {}

    file.content_type.tap do |content_type|
      next if content_type.blank?

      kw_args[:tags] = ["content_type:#{content_type.split('/')[1]}"]
    end

    StatsD.measure(*args, **kw_args)
  end
end
