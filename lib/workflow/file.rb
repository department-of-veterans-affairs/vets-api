# frozen_string_literal: true

class Workflow::File < Workflow::Base
  def initialize(file, **options)
    raise 'First argument must be a Shrine::Attacher' unless file.is_a?(Shrine::Attacher)
    super(**options)
    # extract the shrine file data.
    @internal_options[:file] = file.read
    @internal_options[:attacher_class] = file.class.to_s
    @internal_options[:history] = []
  end
end
