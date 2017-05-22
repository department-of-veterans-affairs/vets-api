# frozen_string_literal: true
require 'workflow/task'

module Workflow::Task::ShrineFile
  class Base < Workflow::Task
    attr_accessor :file, :attacher
    def initialize(args = {}, internal: {})
      super
      internal[:history] ||= []
      file_handle = json_to_file_handle(internal[:file])
      attacher.set(file_handle)
      @file = attacher.get
      add_version(attacher.read, tag: 'initial version') if history.empty?
    end

    def update_file(io: nil, **rest)
      attacher.assign(io) # TODO: what to do if validations fail at this step?
      add_version(@attacher.read, **rest)
    end

    def history
      internal[:history].map do |record|
        json_to_file_handle(record[:file])
      end
    end

    def attacher
      file_class = internal[:attacher_class]&.constantize || Shrine::Attacher
      @attacher ||= file_class.new(InternalAttachment.new(**data), :file)
    end

    def json_to_file_handle(json)
      file_json = JSON.parse(json)
      attacher.uploaded_file(file_json)
    end

    private

    def add_version(file, **rest)
      internal[:file] = file
      record = { file: file }.merge(rest.merge(task: self.class.to_s, added: Time.current.to_s)).merge(user_args: data)
      internal[:history] << record
      @file = attacher.get
    end
  end
end
