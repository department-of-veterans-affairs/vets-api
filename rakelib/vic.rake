# frozen_string_literal: true

require './rakelib/support/vic_load_test'
require 'vic/service'

namespace :vic do
  task test_connection: :environment do
    client = VIC::Service.new.get_client

    puts 'connection works' if client.user_info.class == Restforce::Mash
  end

  N = 10

  desc 'Load test document uploads using faraday'
  task :load_test_doc, [:host] => :environment do |_, args|
    LoadTest.measure_elapsed do
      N.times do
        LoadTest.conn(args[:host], 'supporting_documentation_attachments').post do |req|
          req.body = LoadTest.doc_png_payload
        end
      end
    end
  end

  desc 'Load test photo uploads using faraday'
  task :load_test_photo, [:host] => :environment do |_, args|
    LoadTest.measure_elapsed do
      N.times do
        LoadTest.conn(args[:host], 'profile_photo_attachments').post do |req|
          req.body = LoadTest.photo_payload
        end
      end
    end
  end
end
