# frozen_string_literal: true

module FixtureHelpers
  extend ActiveSupport::Concern

  module ClassMethods
    def get_fixture(path)
      JSON.parse(File.read("spec/fixtures/#{path}.json"))
    end

    def get_fixture_absolute(path)
      JSON.parse(File.read("#{path}.json"))
    end
  end

  def get_fixture(*args)
    self.class.public_send(__method__, *args)
  end

  def get_fixture_absolute(*args)
    self.class.public_send(__method__, *args)
  end
end
