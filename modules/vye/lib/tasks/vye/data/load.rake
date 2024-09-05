# frozen_string_literal: true

namespace :vye do
  namespace :data do
    desc 'Load development YAML files into the database'
    task :load, [:path] => :environment do |_cmd, args|
      raise 'load path is required' if args[:path].nil?

      root = Pathname(args[:path])
      files = root.glob('**/*.yaml')
      raise "No files found in #{root}" if files.empty?

      bdn_clone = Vye::BdnClone.create!(transact_date: Time.zone.today)

      files.each do |file|
        source = :team_sensitive
        locator = format('file: %<name>s', name: file.basename)
        data = YAML.safe_load(file.read, permitted_classes: [Date, DateTime, Symbol, Time])
        records = data.slice(:profile, :info, :address, :awards, :pending_documents)
        if Vye::LoadData.new(source:, locator:, bdn_clone:, records:).valid?
          $stdout.puts format('Vye::LoadData(%<source>s, %<locator>s): succeeded', source:, locator:)
        else
          $stdout.puts format('Vye::LoadData(%<source>s, %<locator>s): failed', source:, locator:)
        end
      end

      id = bdn_clone.id
      count = bdn_clone.activate!
      $stdout.puts format('Vye::BdnClone(%<id>u): activated with %<count>u count UserInfo', id:, count:)
    end
  end
end
