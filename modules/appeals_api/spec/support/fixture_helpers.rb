# frozen_string_literal: true

module FixtureHelpers
  def fixture_to_s(filename, version: '')
    File.read fixture_filepath(filename, version:)
  end

  def fixture_as_json(filename, version: '')
    JSON.parse fixture_to_s(filename, version:)
  end

  def fixture_filepath(filename, version: '')
    Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', version, filename)
  end
end
