# frozen_string_literal: true

module VetsApi
  module Commands
    class Info
      class << self
        def run
          puts <<~INFO
            Rails version:      #{Rails.version}
            Ruby version:       #{RUBY_DESCRIPTION}
            Gem version:        #{gem_version}
            Bundler version:    #{bundler_version}
            Environment:        #{Rails.env}
            Postgres Version:   #{postgres_version}
            Redis version:      #{redis_version}
            Docker:             #{docker_version}
            Host OS:            #{RbConfig::CONFIG['host_os']}
            Commit SHA:         #{commit_sha}
            Latest Migration:   #{latest_migration_timestamp}
          INFO
        end

        private

        def gem_version
          `gem --version`.chomp
        end

        def bundler_version
          `bundle --version`.chomp
        end

        def postgres_version
          `postgres --version`.chomp
        rescue
          'Not Found'
        end

        def redis_version
          `redis-cli --version`.chomp
        rescue
          'Not Found'
        end

        def docker_version
          `docker -v`&.chomp # rubocop:disable Lint/RedundantSafeNavigation
        rescue
          'Not Found'
        end

        def commit_sha
          `git log --pretty=format:'%h' -n 1`
        end

        def latest_migration_timestamp
          `psql -d vets-api -t -A -c "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1;"`
        end
      end
    end
  end
end
