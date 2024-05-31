# frozen_string_literal: true

namespace :vye do
  namespace :data do
    desc 'Build YAML files to load for development from team sensitive data'
    task build: :environment do |_cmd, _args|
      source = Pathname('/projects/va.gov-team-sensitive')
      target = Rails.root / 'tmp'
      handles = nil

      build = Vye::StagingData::Build.new(target:) do |paths|
        handles =
          paths
          .transform_values do |value|
            (source / value).open
          end
      end

      build.dump
      handles.each_value(&:close)
    end
  end
end
