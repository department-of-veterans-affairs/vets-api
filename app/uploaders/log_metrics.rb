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

    %w[size content_type].each do |attr|
      StatsD.measure("#{class_prefix}.#{attr}", file.public_send(attr))
    end
  end
end
