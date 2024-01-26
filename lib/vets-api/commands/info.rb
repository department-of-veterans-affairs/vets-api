module VetsApi
  module Commands
    class Info
      def self.run
        puts <<~INFO
          Rails version:      #{Rails.version}
          Ruby version:       #{RUBY_DESCRIPTION}
          Environment:        #{Rails.env}
          Docker:             #{`docker -v`&.chomp}
          Host OS:            #{RbConfig::CONGIF}
          Commit:             #{`git log -1 --format=%H`}
        INFO
      end
    end
  end
end
