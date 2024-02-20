# frozen_string_literal: true
require 'pry'

module VetsApi
  module Commands
    class Test
      class << self

        attr_accessor :options, :inputs

        def run(args)
          @options = args.select { |a| a.start_with?('--', '-') }
          input_values = args.reject { |a| a.start_with?('--', '-') }
          @inputs =  input_values.empty? ? 'spec modules' : input_values.join(' ')

          case File.read('.developer-environment')
          when 'native', 'hybrid'
            test_native
          when 'docker'
            test_docker
          else
            puts "Invalid option for .developer-environment"
          end
        end

        private

        def test_native
          puts "running: #{rspec_command_builer}"
          system(rspec_command_builer)
        end

        def test_docker
         system("docker-compose run --rm --service-ports web bash -c \"#{rspec_command_builer}\"")
        end

        # Verbose rspec output is also uses
        # RSPEC_VERBOSE_OUTPUT is used in spec/rails_helper.rb:194
        def rspec_command_builer
          no_coverage = !@options.include?('--coverage')
          verbose = @options.include?('--verbose')
          verbose_out = verbose ? '' : '2> /dev/null'
          "RAILS_ENV=test DISABLE_BOOTSNAP=true NOCOVERAGE=#{no_coverage} RSPEC_VERBOSE_OUTPUT=#{verbose} bundle exec parallel_rspec #{@inputs} #{verbose_out}".rstrip
        end

      end
    end
  end
end
