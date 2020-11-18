# frozen_string_literal: true

$stdout.sync = true
namespace :docker_debugging do
  desc 'Setup environment for debugging in docker'
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
        puts 'Starting db setup'
        Rake::Task['db:drop'].invoke
        Rake::Task['db:create'].invoke
        Rake::Task['db:schema:load'].invoke
        Rails.env = 'test'
        Rake::Task['db:schema:load'].invoke
        puts 'All dun!'
      end
      sh 'foreman start -m all=1,clamd=0,freshclam=0'
    end
  end
end
