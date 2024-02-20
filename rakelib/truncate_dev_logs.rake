# frozen_string_literal: true

namespace :development_logs do
  desc 'Truncate development log'
  task :load, [:path] => [:environment] do |_t, _args|
    file = File.open('log/development.log', 0)
    file.readlines.each do |line|
      line_array = line.split
      if (line_array[0].present? && line_array[0].to_date < (Time.zone.today - 1)) || (line_array[0].present? && line_array[0].include?('/Users'))
        line_array.clear
      end
    end
  end
end
