# frozen_string_literal: true

module CovidResearch
  class RedisFormat
    # initialize assumes that it is receiving Base64 encoded attributes
    # if the data is not yet encoded then no args should be provided and
    #   accessors should be used instead
    def initialize(json = false)
      if json
        json_struct = JSON.parse(json)

        @form_data = json_struct['form_data']
        @iv = json_struct['iv']
      else
        @form_data = nil
        @iv = nil
      end
    end

    def form_data
      Base64.decode64(@form_data)
    end

    def iv
      Base64.decode64(@iv)
    end

    def form_data=(data)
      @form_data = Base64.encode64(data)
    end

    def iv=(data)
      @iv = Base64.encode64(data)
    end

    def to_json(opts = {})
      h = {
        form_data: @form_data,
        iv: @iv
      }

      if opts[:only]
        h.keep_if { |key, _value| opts[:only].include key }
      elsif opts[:except]
        k.keep_if { |key, _value| !opts[:except].include(key) }
      end

      JSON.generate(h)
    end
  end
end
