# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::TimsChunk do
  let(:offset) { 0 }
  let(:block_size) { 1000 }
  let(:filename) { 'test.txt' }

  it 'can be instantiated' do
    expect(described_class.new(offset:, block_size:, filename:)).to be_a described_class
  end

  describe '::feed_filename' do
    it 'returns a string' do
      expect(described_class.send(:feed_filename)).to be_a(String)
    end
  end

  describe '#import' do
    let(:offset) { 0 }
    let(:block_size) { 1000 }
    let(:filename) { 'test-0.txt' }
    let(:chunk) { described_class.new(offset:, block_size:, filename:) }

    let(:file) { Vye::Engine.root / 'spec/fixtures/tims_sample/tims32towave.txt' }

    before do
      create(:vye_user_profile_fresh_import, ssn: '441972624', file_number: '227366592')
      create(:vye_user_profile_fresh_import, ssn: '596100167', file_number: '662929072')
      create(:vye_user_profile_fresh_import, ssn: '194889304', file_number: '301143261')
      create(:vye_user_profile_fresh_import, ssn: '261045161', file_number: '704243999')
      create(:vye_user_profile_fresh_import, ssn: '036662203', file_number: '690756310')
      create(:vye_user_profile_fresh_import, ssn: '942504788', file_number: '738416685')
      create(:vye_user_profile_fresh_import, ssn: '261077041', file_number: '823716203')
      create(:vye_user_profile_fresh_import, ssn: '970447691', file_number: '420365151')
      create(:vye_user_profile_fresh_import, ssn: '151014371', file_number: '948813522')
      create(:vye_user_profile_fresh_import, ssn: '807164639', file_number: '444442869')
      create(:vye_user_profile_fresh_import, ssn: '124496046', file_number: '114591317')
      create(:vye_user_profile_fresh_import, ssn: '045274951', file_number: '037619065')
      create(:vye_user_profile_fresh_import, ssn: '500042905', file_number: '732531728')
      create(:vye_user_profile_fresh_import, ssn: '333224444', file_number: '883200138')
      create(:vye_user_profile_fresh_import, ssn: '992549762', file_number: '333224444')
    end

    it 'only loads when there is a UserProfile that matches' do
      expect(chunk).to receive(:file).and_return(file)

      expect do
        chunk.import
      end.to(change(Vye::PendingDocument, :count).by(13))
    end
  end
end
