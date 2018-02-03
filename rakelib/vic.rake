# frozen_string_literal: true

namespace :vic do
  desc 'Load test VIC uploads'
  task load_test: :environment do
    MEGABYTE = 1024 * 1024
    UPLOAD_TYPE = ::VIC::ProfilePhotoAttachment

    N = 100
    FILE_SIZE = 10 * MEGABYTE

    uploads = []
    filenames = []

    t0 = Time.zone.now

    N.times do
      data = NamedStringIO.new('load_test.jpg', Random.new.bytes(FILE_SIZE))

      upload = UPLOAD_TYPE.new
      upload.set_file_data!(data)
      upload.save!

      uploads << upload
      filenames << JSON.parse(upload.file_data)['filename']
    end

    t1 = Time.zone.now
    elapsed = t1 - t0

    UPLOAD_TYPE.destroy(uploads.map(&:id))

    puts
    puts "Start:      #{t0}"
    puts "End:        #{t1}"
    puts "Elapsed:    #{elapsed.round(2)} seconds"

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
