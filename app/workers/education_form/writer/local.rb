# frozen_string_literal: true
module EducationForm
  class Writer::Local
    def initialize(logger:)
      @logger = logger
      @dir = Rails.root.join('tmp', 'spool_files')
      FileUtils.mkdir_p(@dir)
    end

    def close
      true
    end

    def write(contents, filename)
      File.open(File.join(@dir, filename), 'w') do |f|
        f.write(contents)
      end
    end
  end
end
