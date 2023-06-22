# frozen_string_literal: true

require 'forwardable'

module FixtureHelpers
  extend Forwardable

  def self.fixture_filepath(path_within_fixtures)
    AppealsApi::Engine.root.join('spec', 'fixtures', path_within_fixtures)
  end

  def self.fixture_to_s(path_within_fixtures)
    File.read fixture_filepath(path_within_fixtures)
  end

  def self.fixture_as_json(path_within_fixtures)
    JSON.parse fixture_to_s(path_within_fixtures)
  end

  def_delegator self, :fixture_filepath
  def_delegator self, :fixture_to_s
  def_delegator self, :fixture_as_json
end
