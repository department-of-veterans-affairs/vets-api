# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::StagingData::Writer do
  let(:writer) do
    source = Pathname('/dev/null')
    target = Pathname('/dev/null')
    Vye::StagingData::Writer.new(source:, target:)
  end

  describe '#output_root' do
    it 'returns a Pathname' do
      expect(writer.output_root).to be_a(Pathname)
    end
  end

  # describe '#db_rows' do
  #   it 'returns an array of Hashes' do
  #     expect(Vye::StagingData::Writer.new.db_rows).to all(be_a(Hash))
  #   end
  # end

  # describe '#report_rows' do
  #   it 'returns an array of Hashes' do
  #     expect(Vye::StagingData::Writer.new.report_rows).to all(be_a(Hash))
  #   end
  # end

  # describe '#perform' do
  #   let(:writer) { Vye::StagingData::Writer.new }

  #   it 'writes a file for each row' do
  #     expect(writer.output_root).to receive(:mkpath).and_return(true)
  #     expect(writer.db_rows).to receive(:each).and_return(true)
  #     expect { writer.perform }.not_to raise_error
  #   end
  # end
end
