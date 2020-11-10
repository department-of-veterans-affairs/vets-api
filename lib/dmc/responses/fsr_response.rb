# frozen_string_literal: true

module DMC
  class FSRResponse
    def initialize(res)
      @res = res
    end

    def status
      @res['status']
    end
  end
end
