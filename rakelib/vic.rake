# frozen_string_literal: true

require './rakelib/support/vic_load_test'

namespace :vic do
  N = 10

  desc 'Load test document uploads using faraday'
  task load_test_doc: :environment do
    LoadTest.measure_elapsed do
      N.times do
        LoadTest.conn('supporting_documentation_attachments').post do |req|
          req.body = LoadTest.doc_png_payload
        end
      end
    end
  end

  desc 'Load test photo uploads using faraday'
  task load_test_photo: :environment do
    LoadTest.measure_elapsed do
      N.times do
        LoadTest.conn('profile_photo_attachments').post do |req|
          req.body = LoadTest.photo_payload
        end
      end
    end
  end

  desc 'Load test VIC uploads'
  task load_test_photo_models: :environment do
    MEGABYTE = 1024 * 1024
    FILE_SIZE = 10 * MEGABYTE

    uploads = []
    filenames = []

    LoadTest.measure_elapsed do
      N.times do
        data = NamedStringIO.new('load_test.jpg', Random.new.bytes(10 * MEGABYTE))

        upload = UPLOAD_TYPE.new
        upload.set_file_data!(data)
        upload.save!

        uploads << upload
        filenames << JSON.parse(upload.file_data)['filename']
      end
    end

    UPLOAD_TYPE.destroy(uploads.map(&:id))

    log_filename = "load_test_#{t0.strftime('%H_%M_%S')}.txt"
    File.open(log_filename, 'w+') do |f|
      f.puts(filenames)
    end
    puts "Upload log: #{log_filename}"
  end

  # https://github.com/carrierwaveuploader/carrierwave/wiki/How-to:-Upload-from-a-string-in-Rails-3-or-later
  class NamedStringIO < StringIO
    attr_accessor :filepath

    def initialize(*args)
      super(*args[1..-1])
      @filepath = args[0]
    end

    def original_filename
      File.basename(@filepath)
    end
  end
end
