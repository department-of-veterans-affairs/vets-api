# frozen_string_literal: true

require 'benchmark'

desc <<~TEXT
  Compare `Tempfile` vs `StringIO` in terms of performance and output when
  constructing HTTP requests that include files.

  Check this classic short piece called "Latency Numbers Every Programmer Should Know"
  Adapted at: https://gist.github.com/hellerbarde/2843375

  EXAMPLES
    bundle exec rails iodemo
TEXT

task iodemo: :environment do
  IoDemo.compare_output
  IoDemo.compare_performance

  ##
  # COMPARISON OF FILE VS STRING APPROACHES:
  #
  #   FILE REQUEST HEADERS:
  #
  #     {
  #       "User-Agent" => "Faraday v2.14.0",
  #       "Content-Type" => "multipart/form-data; boundary=-----------RubyMultipartPost-5af8883ff2befafaa2f37299f636b457",
  #       "Content-Length" => "13001"
  #     }
  #
  #   FILE REQUEST BODY:
  #
  #     -------------RubyMultipartPost-5af8883ff2befafaa2f37299f636b457
  #     Content-Disposition: form-data; name="file"; filename="birth-certificate1.pdf20260205-76104-4ne5vp"
  #     Content-Length: 12675
  #     Content-Type: application/pdf
  #     Content-Transfer-Encoding: binary
  #
  #   STRING REQUEST HEADERS:
  #
  #   {
  #     "User-Agent" => "Faraday v2.14.0",
  #     "Content-Type" => "multipart/form-data; boundary=-----------RubyMultipartPost-57c2dd5dfac3e8bee7dac9a5511685d2",
  #     "Content-Length" => "12980"
  #   }
  #
  #   STRING REQUEST BODY:
  #
  #     -------------RubyMultipartPost-57c2dd5dfac3e8bee7dac9a5511685d2
  #     Content-Disposition: form-data; name="file"; filename="birth-certificate1.pdf"
  #     Content-Length: 12675
  #     Content-Type: application/pdf
  #     Content-Transfer-Encoding: binary
  #
  #   BENCHMARKING 1000 RUNS PER APPROACH:
  #
  #                                user     system      total        real
  #     `Tempfile` total         0.313640   0.141964   0.455604 (  0.469231)
  #     `StringIO` total         0.000703   0.000001   0.000704 (  0.000704)
  #
  #     `Tempfile` avg: 0.4692 ms/run
  #     `StringIO` avg: 0.0007 ms/run
  #
  #     `Tempfile` slowdown: 666.52x slower than `StringIO`
  ##
end

module IoDemo
  FILE_NAME = 'birth-certificate1.pdf'
  MIME_TYPE = MimeMagic.by_path(FILE_NAME).type

  ##
  # Just some random file on my system, much smaller than we'd typically see in
  # this codepath. Feel free to try your own.
  #
  FILE_BODY = File.read(Rails.root.join("tmp/disability_compensation/download_claim_documents/600878948/#{FILE_NAME}"))

  class << self
    ##
    # The file-system roundtrip approach.
    #
    # Inefficient + error-prone:
    # - We already have the file body in memory, yet this writes it all the way
    #   to disk, just to immediately reread it back from disk again
    # - In that hugely expensive file-system roundtrip, it also now exposes us
    #   to the file-system yelling at us for `Errno::ENAMETOOLONG`
    #
    # This original approach made no sense. The `file_body` is already in
    # memory. Hard-disk access is the slowest possible IO operation other than
    # network access. (Network request happens right after this anyway, dwarfing
    # the disk usage, but still good to care about disk usage anyway).
    #
    def build_io_file
      file = Tempfile.new(FILE_NAME)
      File.write(file, FILE_BODY)
      Faraday::UploadIO.new(file, MIME_TYPE)
    end

    ##
    # Alternative that doesn't use `Tempfile` and uses the file body that is
    # already in memory.
    #
    def build_io_string
      string = StringIO.new(FILE_BODY)
      Faraday::UploadIO.new(string, MIME_TYPE, FILE_NAME)
    end

    def capture_request(io)
      {}.tap do |memo|
        conn = Faraday.new('https://example.test') do |f|
          f.request :multipart
          f.adapter :test do |stub|
            stub.post('/upload') do |env|
              memo[:headers] = env.request_headers
              memo[:body] = env.request_body.read[/.*?binary/m]

              [200, {}, 'ok']
            end
          end
        end

        conn.post(
          '/upload',
          file: io
        )
      end
    end

    def compare_output
      file_request = capture_request(build_io_file)
      string_request = capture_request(build_io_string)

      puts 'FILE REQUEST HEADERS:'
      puts file_request[:headers]
      puts
      puts 'FILE REQUEST BODY:'
      puts file_request[:body]
      puts
      puts 'STRING REQUEST HEADERS:'
      puts string_request[:headers]
      puts
      puts 'STRING REQUEST BODY:'
      puts string_request[:body]
    end

    ITERATIONS = 1_000

    def compare_performance
      puts
      puts "BENCHMARKING #{ITERATIONS} RUNS PER APPROACH:"
      puts

      tempfile_bm = nil
      stringio_bm = nil

      Benchmark.bm(20) do |x|
        tempfile_bm = x.report('`Tempfile` total') { ITERATIONS.times { build_io_file } }
        stringio_bm = x.report('`StringIO` total') { ITERATIONS.times { build_io_string } }
      end

      tempfile_avg_ms = (tempfile_bm.real * 1000.0) / ITERATIONS
      stringio_avg_ms = (stringio_bm.real * 1000.0) / ITERATIONS
      slowdown = tempfile_bm.real / stringio_bm.real

      puts
      puts format('`Tempfile` avg: %.4f ms/run', tempfile_avg_ms)
      puts format('`StringIO` avg: %.4f ms/run', stringio_avg_ms)
      puts
      puts format('`Tempfile` slowdown: %.2fx slower than `StringIO`', slowdown)
      puts
    end
  end
end
