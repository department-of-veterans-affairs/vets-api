# frozen_string_literal: true
require 'workflow/task'

module Workflow::Task::ShrineFile
  class Base < Workflow::Task
    attr_accessor :file, :attacher
    def initialize(args = {}, internal: {})
      super
      internal[:history] = []
      file_json = JSON.parse(internal[:file])
      file_handle = attacher.uploaded_file(file_json)
      attacher.set(file_handle)
      @file = attacher.get
      add_version(attacher.read, tag: 'initial version') if history.empty?
    end

    def update_file(io: nil, **rest)
      attacher.assign(io) # TODO: what to do if validations fail at this step?
      add_version(@attacher.read, **rest)
      @file = attacher.get
    end

    def history
      internal[:history].map do |record|
        parsed = JSON.parse(record[:file])
        @attacher.uploaded_file(parsed)
      end
    end

    def attacher
      file_class = internal[:attacher_class]&.constantize || Shrine::Attacher
      @attacher ||= file_class.new(InternalAttachment.new(**data), :file)
    end

    private

    def add_version(file, **rest)
      internal[:file] = file
      record = { file: file }.merge(rest.merge(task: self.class.to_s)).merge(user_args: data)
      logger.info "Adding #{file} to history"
      internal[:history] << record
    end
  end
end
