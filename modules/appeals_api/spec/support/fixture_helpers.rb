# frozen_string_literal: true

require 'forwardable'

module FixtureHelpers
  extend Forwardable

  def self.fixture_filepath(path_within_fixtures, version: '')
    if version.present?
      # FIXME: the `version` argument in these methods exists only to be backwards-compatible with test code from before
      # changes made in API-26837, which involved too many changed lines to merge at once. The `version` argument will
      # soon be removed in favor of expecting a full subpath within the fixtures directory instead of assuming that a
      # JSON file is in the decision_reviews directory and a PDF is in the pdf directory as we do here:
      dir = path_within_fixtures.ends_with?('pdf') ? 'pdf' : 'decision_reviews'
      FixtureHelpers.fixture_filepath(
        "#{dir}/#{version}/#{path_within_fixtures}"
      )
    else
      AppealsApi::Engine.root.join('spec', 'fixtures', path_within_fixtures)
    end
  end

  def self.fixture_to_s(path_within_fixtures, version: '')
    File.read fixture_filepath(path_within_fixtures, version:)
  end

  def self.fixture_as_json(path_within_fixtures, version: '')
    JSON.parse fixture_to_s(path_within_fixtures, version:)
  end

  def_delegator self, :fixture_filepath
  def_delegator self, :fixture_to_s
  def_delegator self, :fixture_as_json
end
