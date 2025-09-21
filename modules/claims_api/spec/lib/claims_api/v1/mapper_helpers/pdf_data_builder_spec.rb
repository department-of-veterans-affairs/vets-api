# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v1/mapper_helpers/pdf_data_builder'

describe ClaimsApi::V1::PdfDataBuilder do
  let(:mock_pdf_mapper) do
    Class.new do
      include ClaimsApi::V1::PdfDataBuilder

      def initialize
        @pdf_data = { data: { attributes: {} } }
      end
    end
  end

  let(:instance) { mock_pdf_mapper.new }

  describe '#build_pdf_path' do
    it 'build the empty hash' do
      result = instance.build_pdf_path(:identification_info)

      expect(result).to eq({})
    end

    it 'does not overwrite data when the key already exists' do
      # create the structure
      first_call = instance.build_pdf_path(:identification_info)
      first_call[:existing] = 'data'

      # return the same hash with data
      second_call = instance.build_pdf_path(:identification_info)

      expect(second_call).to eq({ existing: 'data' }) # should not be overwritten
    end
  end
end
