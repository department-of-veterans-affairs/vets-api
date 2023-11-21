# frozen_string_literal: true

SecureRandom.define_singleton_method(:hex) do |n = nil|
  s = super(n)
  Thread.current['job_ids'] ||= []
  Thread.current['job_ids'] << s
  s
end
