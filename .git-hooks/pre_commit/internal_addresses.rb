# frozen_string_literal: true

module Overcommit::Hook::PreCommit
  class InternalAddresses < Base
    def run
      errors = []
      unparsable = []

      applicable_files.each do |file|
        begin
          contents = File.read(file)
          errors << "#{file}: Includes 10.X.Y.Z address" if contents.match?(/10\.\d+\.\d+\.\d+/)
          errors << "#{file}: Includes vaww address" if contents.match?(/vaww\./)
        rescue StandardError
          unparsable << "Could not match against #{file}"
        end
      end

      return :fail, errors.join("\n") if errors.any?

      :pass
    end
  end
end
