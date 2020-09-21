# frozen_string_literal: true

require 'rails/generators'

class ProviderStateGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  def create_provider_state_file
    template 'provider_states.rb.erb', "spec/service_consumers/provider_states_for/#{file_name}.rb"
  end

  # rubocop:disable Rails/Output
  # :nocov:
  def generator_output
    puts "\n"
    puts "\u{1F64C} new pact provider state generated"
    puts "Generated at: spec/service_consumers/provider_states_for/#{file_name}.rb \n\n"
    puts "\n"
  end
  # :nocov:
  # rubocop:enable Rails/Output
end
