# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Form0781 < AncillaryFormPopulator
      def translate
        return nil unless @veteran_data && @final_output
        @final_output['veteranSecondaryPhone'] = '' # No secondary phone available in 526 PreFill
        @final_output
      end
    end
  end
end
