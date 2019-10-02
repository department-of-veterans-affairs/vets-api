# frozen_string_literal: true

module FlipperExtensions
  module ConfigurationPatch
    # This attr exists in latest version of Flipper.
    # To be removed after updating the gem.
    attr_accessor :add_actor_placeholder
    attr_accessor :custom_views_path

    def initialize
      super
      @add_actor_placeholder = 'a flipper id'
      @custom_views_path = nil
    end
  end
end
