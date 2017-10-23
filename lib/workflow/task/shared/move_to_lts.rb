# frozen_string_literal: true

# MoveToLTS is a Workflow Task that uses Shrine to move
# either the most recently processed copy of an uploaded file,
# or all versions of a file, to it's `store`, which is a more
# persistent long term storage than it's `cache`, where the file(s)
# resided before.

module Workflow::Task::Shared
  class MoveToLTS < Workflow::Task::ShrineFile::Base
    def run(options = {})
      if options&.key?(:all)
        history.map do |record|
          promote(record)
        end
      else
        promote(file)
      end
      clear_cached!
    end

    def promote(record)
      promoted = attacher.promote(record)
      attacher.set(promoted)
      add_version(attacher.read, tag: 'promoted')
    end

    def clear_cached!
      history.select do |item|
        item.data['storage'] == 'cache'
      end.map(&:delete)
    end
  end
end
