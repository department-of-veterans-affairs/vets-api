# frozen_string_literal: true

module FixtureHelpers
  def fixture_to_s(filename)
    File.read fixture_filepath(filename)
  end

  def fixture_as_json(filename)
    JSON.parse fixture_to_s filename
  end

  def fixture_filepath(filename)
    Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', filename)
  end
end
