# frozen_string_literal: true

require 'rails/generators'

class ProviderStateGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  def create_provider_state_file
    template 'provider_states.rb.erb', "spec/service_consumers/provider_states_for/#{file_name}.rb"

    # rubocop:disable Rails/Output
    # :nocov:

    puts "\n"
    puts "\u{1F64C} new pact provider state generated at spec/service_consumers/provider_states_for/#{file_name}.rb \n\n"
    puts "\n"

    # :nocov:
    # rubocop:enable Rails/Output
  end
end
