# frozen_string_literal: true

$stdout.sync = true
namespace :docker_debugging do
  desc 'Setup environment for debugging in docker'
  command = 'foreman start -m all=1,clamd=0,freshclam=0'
  task setup: :environment do |_task|
    if Settings.docker_debugging
      raise 'This rake task runs in development mode only!' unless Rails.env.development?

      s = Settings.docker_debugging
      if s.hang_around
        puts 'Just hanging around, you can:'
        puts 'docker exec -it some_container_id bash'
        Thread.send(:new) { loop {} }.join
      end
      if s.set_up_db
        Rake::Task['db:drop'].invoke
        Rake::Task['db:create'].invoke
        Rake::Task['db:schema:load'].invoke
        Rake::Task['db:migrate'].invoke
        puts 'All dun!'
      end
      if s.enable_sidekiq_debugging
        puts 'Sidekiq debugging is enabled'
        command += ',job=0'
      end
      sh command
    end
  end
end
