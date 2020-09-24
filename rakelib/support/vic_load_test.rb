# frozen_string_literal: true

module LoadTest
  module_function

  def measure_elapsed
    t0 = Time.zone.now
    yield
    t1 = Time.zone.now
    elapsed = t1 - t0

    puts
    puts "Start:      #{t0}"
    puts "End:        #{t1}"
    puts "Elapsed:    #{elapsed.round(2)} seconds"
  end

  def conn(host, route)
    Faraday.new("#{host}/v0/vic/#{route}") do |c|
      c.request :multipart
      c.request :url_encoded
      c.adapter Faraday.default_adapter
    end
  end

  def photo_payload
    {
      profile_photo_attachment: {
        file_data: Faraday::UploadIO.new(
          Rails.root.join('rakelib', 'support', 'files', 'example_10mb.png').to_s,
          'image/png'
        )
      }
    }
  end

  def doc_png_payload
    {
      supporting_documentation_attachment: {
        file_data: Faraday::UploadIO.new(
          Rails.root.join('rakelib', 'support', 'files', 'example_10mb.png').to_s,
          'image/png'
        )
      }
    }
  end

  def doc_pdf_payload
    {
      supporting_documentation_attachment: {
        file_data: Faraday::UploadIO.new(
          Rails.root.join('rakelib', 'support', 'files', 'example_25mb.pdf').to_s,
          'image/png'
        )
      }
    }
  end
end
