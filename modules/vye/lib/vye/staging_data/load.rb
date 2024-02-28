# frozen_string_literal: true

module Vye
  module StagingData
    module Vye::StagingData::Load
      module_function

      def from_path(source)
        files = Pathname(source).glob('**/*.yaml')
        raise "No files found in #{source}" if files.empty?

        files.each do |file|
          data = YAML.load_file(file)
          ui = UserInfo.create!(data['user_info'])
          data['awards'].each do |award|
            ui.awards.create!(award)
          end
          data['pending_documents'].each do |pending_document|
            ui.pending_documents.create!(pending_document)
          end
        end
      end
    end
  end
end
