# frozen_string_literal: true

RSpec::Matchers.define :match_episode_body do |expected|
  match do |actual|
    actual == expected
  end

  failure_message do |actual|
    message = "expected that #{actual} would match #{expected}"
    outputs = [actual, expected].map { |a| pretty(a) }
    message += "\nDiff:#{differ.diff_as_string(*outputs)}"
    message
  end

  def pretty(output)
    JSON.pretty_generate(JSON.parse(output))
  rescue
    output
  end

  def differ
    RSpec::Support::Differ.new(
      object_preparer: ->(object) { RSpec::Matchers::Composable.surface_descriptions_in(object) },
      color: RSpec::Matchers.configuration.color?
    )
  end
end
