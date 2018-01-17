# frozen_string_literal: true

# Used by the FileUpload class to give Shrine something to
# latch onto for file and metadata storage.
class InternalAttachment
  attr_accessor :file_data

  # Allow us to set attributes that directly impact the file
  # or that Shrine plugins may need to use. For instance,
  # :user_id could be passed in and used to generate a partial
  # file path. These options are also passed through to the
  # background processing workflow.
  def initialize(args = {})
    args.each { |k, v| instance_variable_set("@#{k}", v) }
  end

  def method_missing(method_name, *arguments, &block)
    instance_variable_get "@#{method_name}" || super
  end

  def respond_to_missing?(method_name, include_private = false)
    instance_variable_defined?("@#{method_name}") || super
  end
end
