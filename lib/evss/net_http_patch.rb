module EVSS
  module NetHttpPatch
    refine Net::HTTPGenericRequest do
      # :nocov:
      def capitalize(name)
        name
      end
      # :nocov:
    end
  end
end
