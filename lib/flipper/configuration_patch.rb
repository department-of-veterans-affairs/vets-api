# frozen_string_literal: true

module FlipperExtensions
  module ConfigurationPatch
    attr_accessor :custom_views_path

    def initialize
      super
      @custom_views_path = nil
    end
  end
end
