# frozen_string_literal: true

module FormProfiles
  module FormUpload
    class Base < FormProfile
      def metadata
        {
          version: 0,
          prefill: true
        }
      end
    end
  end
end
