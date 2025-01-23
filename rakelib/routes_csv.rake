# frozen_string_literal: true

namespace :routes do
  desc 'Print out all defined routes in CSV format.'
  task csv: :environment do
    all_routes = Rails.application.routes.routes
    require 'action_dispatch/routing/inspector'
    inspector = ActionDispatch::Routing::RoutesInspector.new(all_routes)
    puts inspector.format(CSVFormatter.new)
  end
end

class CSVFormatter
  def initialize
    @buffer = []
  end

  def result
    @buffer.join("\n")
  end

  def section_title(title)
    @buffer << "\n#{title}:"
  end

  def section(routes)
    routes.map do |r|
      @buffer << "#{r[:path]},#{r[:reqs]}"
    end
  end

  def header(_routes)
    @buffer << 'Prefix,Controller#Action'
  end

  def no_routes
    @buffer << <<~MESSAGE
      You don't have any routes defined!
      Please add some routes in config/routes.rb.
      For more information about routes, see the Rails guide: http://guides.rubyonrails.org/routing.html.
    MESSAGE
  end
end
