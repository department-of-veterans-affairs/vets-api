# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PersistentAttachments::VAForm, :uploader_helpers do
  let(:file) { Rails.root.join('spec', 'fixtures', 'files', 'marriage-certificate.pdf') }
  let(:instance) { described_class.new }

  before do
    allow(Common::VirusScan).to receive(:scan).and_return(true)
  end

  it 'sets a guid on initialize' do
    expect(instance.guid).to be_a(String)
  end

  it 'allows adding a file' do
    allow_any_instance_of(ClamAV::PatchClient).to receive(:safe?).and_return(true)
    instance.file = file.open
    expect(instance.valid?).to be(true)
    expect(instance.file.shrine_class).to be(FormUpload::Uploader)
  end

  describe '#max_pages' do
    context 'form_id 21-0779' do
      before { instance.form_id = '21-0779' }

      it 'returns 4' do
        expect(instance.max_pages).to eq 4
      end
    end

    context 'form_id 21-509' do
      before { instance.form_id = '21-509' }

      it 'returns 4' do
        expect(instance.max_pages).to eq 4
      end
    end

    context 'form_id 21-686c' do
      before { instance.form_id = '21-686c' }

      it 'returns 16' do
        expect(instance.max_pages).to eq 16
      end
    end

    context 'form_id 21P-0518-1' do
      before { instance.form_id = '21P-0518-1' }

      it 'returns 2' do
        expect(instance.max_pages).to eq 2
      end
    end

    context 'form_id 21P-0516-1' do
      before { instance.form_id = '21P-0516-1' }

      it 'returns 2' do
        expect(instance.max_pages).to eq 2
      end
    end

    context 'form_id 21P-530a' do
      before { instance.form_id = '21P-530a' }

      it 'returns 2' do
        expect(instance.max_pages).to eq 2
      end
    end

    context 'form_id 21P-8049' do
      before { instance.form_id = '21P-8049' }

      it 'returns 4' do
        expect(instance.max_pages).to eq 4
      end
    end

    context 'form_id 40-1330M' do
      before { instance.form_id = '40-1330M' }

      it 'returns 10' do
        expect(instance.max_pages).to eq 10
      end
    end

    context 'default' do
      it 'returns 10' do
        expect(instance.max_pages).to eq 10
      end
    end
  end

  describe '#min_pages' do
    context 'form_id 40-1330M' do
      before { instance.form_id = '40-1330M' }

      it 'returns 1' do
        expect(instance.min_pages).to eq 1
      end
    end

    context 'form_id 21-0779' do
      before { instance.form_id = '21-0779' }

      it 'returns 2' do
        expect(instance.min_pages).to eq 2
      end
    end

    context 'form_id 21-509' do
      before { instance.form_id = '21-509' }

      it 'returns 2' do
        expect(instance.min_pages).to eq 2
      end
    end

    context 'form_id 21P-0518-1' do
      before { instance.form_id = '21P-0518-1' }

      it 'returns 2' do
        expect(instance.min_pages).to eq 2
      end
    end

    context 'form_id 21P-0516-1' do
      before { instance.form_id = '21P-0516-1' }

      it 'returns 2' do
        expect(instance.min_pages).to eq 2
      end
    end

    context 'form_id 21-686c' do
      before { instance.form_id = '21-686c' }

      it 'returns 2' do
        expect(instance.min_pages).to eq 2
      end
    end

    context 'default' do
      it 'returns 1' do
        expect(instance.min_pages).to eq 1
      end
    end
  end

  describe '#delete_file' do
    stub_virus_scan

    it 'deletes the file after destroying the model' do
      instance.file = file.open
      instance.save!
      shrine_file = instance.file
      expect(shrine_file.exists?).to be(true)
      instance.destroy
      expect(shrine_file.exists?).to be(false)
    end
  end
end
