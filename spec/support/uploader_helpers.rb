# frozen_string_literal: true

require 'common/virus_scan'

module UploaderHelpers
  extend ActiveSupport::Concern

  module ClassMethods
    def stub_virus_scan
      let(:result) do
        {
          safe?: true
        }
      end

      before do
        allow(Common::VirusScan).to receive(:scan).and_return(OpenStruct.new(result))
      end
    end
  end
end
