# frozen_string_literal: true

module VetsApi
  module Commands
    class Test
      class << self

        def run(args)

        end

        private

        def setup_developer_environment
          case File.read('.developer-environment')
          when 'native'
            test_native
          when 'docker'
            test_docker
          when 'hybrid'
            test_hybrid
          else
            puts "Invalid option for .developer-environment"
          end
        end

        def test_native

        end

        def test_docker

        end

        def test_hybrid

        end
      end
    end
  end
end
