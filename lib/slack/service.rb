# frozen_string_literal: true

module Slack
  class Service
    def initialize(params)
      @header = params[:header]
      @text = params[:text]
      @channel = params[:channel]
      @webhook = params[:webhook]
    end

    def notify
      data = {
        text: @header,
        blocks: build_blocks,
        channel: @channel
      }

      uri = URI.parse(@webhook)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
      request.body = data.to_json
      http.request(request)
    end

    private

    def build_blocks
      blocks = []
      @text.each do |block|
        case block[:block_type]
        when 'divider'
          blocks.push({ type: 'divider' })
        when 'section'
          blocks.push(build_section(block[:text], block[:text_type]))
        else
          continue
        end
      end
      blocks
    end

    def build_section(text, text_type)
      {
        "type": 'section',
        "text": {
          "type": text_type,
          "text": text
        }
      }
    end
  end
end
