# frozen_string_literal: true

module FixtureHelpers
  def fixture_to_s(filename)
    File.read(Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', filename))
  end

  def fixture_as_json(filename)
    JSON.parse fixture_to_s filename
  end
end
