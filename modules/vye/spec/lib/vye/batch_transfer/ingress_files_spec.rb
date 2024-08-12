# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::IngressFiles do
  describe '::bdn_feed_filename' do
    it 'returns a string' do
      expect(described_class.send(:bdn_feed_filename)).to be_a(String)
    end
  end

  describe '::tims_feed_filename' do
    it 'returns a string' do
      expect(described_class.send(:tims_feed_filename)).to be_a(String)
    end
  end

  describe '::bdn_import' do
    let(:data) { Vye::Engine.root / 'spec/fixtures/bdn_sample/WAVE.txt' }

    it 'imports the data from the bdn feed' do
      expect do
        described_class.send(:bdn_import, data)
      end.to(
        change(Vye::UserProfile, :count).by(1).and(
          change(Vye::UserInfo, :count).by(1).and(
            change(Vye::Award, :count).by(1)
          )
        )
      )
    end
  end

  describe '::tims_import' do
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
      data = Vye::Engine.root / 'spec/fixtures/tims_sample/tims32towave.txt'
      expect do
        described_class.send(:tims_import, data)
      end.to(change(Vye::PendingDocument, :count).by(13))
    end
  end

  describe '::tims_load' do
    let(:file) { instance_double(Pathname) }

    it 'downloads the dataset and laods it in to the database' do
      expect(described_class).to receive(:download).and_yield(file)
      expect(described_class).to receive(:tims_feed_filename)
      expect(described_class).to receive(:tims_import).with(file)

      described_class.tims_load
    end
  end

  describe '::bdn_load' do
    let(:file) { instance_double(Pathname) }

    it 'downloads the dataset and laods it in to the database' do
      expect(described_class).to receive(:download).and_yield(file)
      expect(described_class).to receive(:bdn_feed_filename)
      expect(described_class).to receive(:bdn_import).with(file)

      described_class.bdn_load
    end
  end
end
