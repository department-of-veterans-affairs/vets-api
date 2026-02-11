# frozen_string_literal: true

require 'rails_helper'

describe IvcChampva::DocumentMerger do
  let(:form_id) { 'vha_10_7959c' }
  let(:current_user) { create(:user) }
  let(:uuid) { SecureRandom.uuid }

  # Use real PDF files from fixtures - Medicare cards and non-mergeable documents
  let(:medicare_front) do
    Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'images',
                    'test-medicare-part-a-and-b-card-front.pdf').to_s
  end
  let(:medicare_back) do
    Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'images',
                    'test-medicare-part-a-and-b-card-back.pdf').to_s
  end
  let(:eob_document) do
    Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'files', 'SampleEOB.pdf').to_s
  end
  let(:other_document) do
    Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'images', 'test_image.pdf').to_s
  end

  let(:file_paths) { [medicare_front, medicare_back, eob_document, other_document] }
  let(:attachment_ids) { ['Front of Medicare card', 'Back of Medicare card', 'EOB', 'Birth Certificate'] }

  let(:merger) do
    described_class.new(form_id, file_paths, attachment_ids, current_user, { uuid: })
  end

  before do
    # Enable master feature flag
    allow(Flipper).to receive(:enabled?).with(:champva_document_merging, current_user).and_return(true)
  end

  after do
    # Clean up any generated merged files
    Dir.glob('tmp/*_merged.pdf').each { |file| FileUtils.rm_f(file) }
  end

  describe '#initialize' do
    it 'sets up the merger with correct attributes' do
      expect(merger.form_id).to eq('vha_10_7959c')
      expect(merger.legacy_form_id).to eq('vha_10_7959c')
      expect(merger.file_paths).to eq(file_paths)
      expect(merger.attachment_ids).to eq(attachment_ids)
      expect(merger.current_user).to eq(current_user)
    end

    it 'handles form version manager integration' do
      versioned_form_id = 'vha_10_7959c_rev2025'
      versioned_merger = described_class.new(versioned_form_id, file_paths, attachment_ids, current_user)

      expect(versioned_merger.form_id).to eq(versioned_form_id)
      expect(versioned_merger.legacy_form_id).to eq('vha_10_7959c')
    end

    it 'raises ArgumentError when form_id is nil' do
      expect do
        described_class.new(nil, file_paths, attachment_ids, current_user)
      end.to raise_error(ArgumentError, 'form_id is required')
    end

    it 'raises ArgumentError when form_id is empty string' do
      expect do
        described_class.new('', file_paths, attachment_ids, current_user)
      end.to raise_error(ArgumentError, 'form_id is required')
    end

    it 'raises ArgumentError when form_id is blank' do
      expect do
        described_class.new('   ', file_paths, attachment_ids, current_user)
      end.to raise_error(ArgumentError, 'form_id is required')
    end

    it 'accepts nil current_user' do
      nil_user_merger = described_class.new(form_id, file_paths, attachment_ids, nil)

      expect(nil_user_merger.current_user).to be_nil
      expect(nil_user_merger.form_id).to eq(form_id)
    end
  end

  describe '#process' do
    context 'when master feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_document_merging, current_user).and_return(false)
      end

      it 'returns original files unchanged' do
        result = merger.process

        expect(result[:merged_file_paths]).to eq(file_paths)
        expect(result[:updated_attachment_ids]).to eq(attachment_ids)
      end
    end

    context 'when merge rules apply' do
      before do
        # Enable specific merge rules
        allow(Flipper).to receive(:enabled?).with('champva_docmerge_10_7959c_medicare', current_user).and_return(true)
        allow(Flipper).to receive(:enabled?).with('champva_docmerge_10_7959c_ohi', current_user).and_return(true)
      end

      it 'merges matching documents and returns merged results' do
        result = merger.process

        # Should have 3 files: 1 merged Medicare card + 2 individual non-mergeable documents
        expect(result[:merged_file_paths].length).to eq(3)
        expect(result[:updated_attachment_ids]).to contain_exactly('Medicare card', 'EOB', 'Birth Certificate')

        # Verify merged Medicare card file exists and has merged naming
        medicare_file = result[:merged_file_paths].find { |path| File.basename(path).include?('_merged.pdf') }
        expect(medicare_file).not_to be_nil
        expect(File.exist?(medicare_file)).to be(true)
        expect(File.basename(medicare_file)).to include('_merged.pdf')

        # Verify non-merged files are the original files
        non_merged_files = result[:merged_file_paths].reject { |path| File.basename(path).include?('_merged.pdf') }
        expect(non_merged_files).to include(eob_document)
        expect(non_merged_files).to include(other_document)
      end

      it 'maintains correct ordering between file paths and attachment IDs' do
        result = merger.process

        # The returned arrays should maintain consistent ordering
        # Each file path should correspond to its attachment ID at the same index
        result[:merged_file_paths].each_with_index do |file_path, index|
          attachment_id = result[:updated_attachment_ids][index]

          if File.basename(file_path).include?('_merged.pdf')
            # Merged files should have the merged attachment ID
            expect(attachment_id).to eq('Medicare card')
          elsif file_path == eob_document
            # EOB document should keep its original attachment ID
            expect(attachment_id).to eq('EOB')
          elsif file_path == other_document
            # Other document should keep its original attachment ID
            expect(attachment_id).to eq('Birth Certificate')
          end
        end

        # Verify we have the expected total count
        expect(result[:merged_file_paths].length).to eq(result[:updated_attachment_ids].length)
      end

      it 'creates valid merged PDF files' do
        result = merger.process

        result[:merged_file_paths].each do |merged_file_path|
          # Verify file exists and has content
          expect(File.exist?(merged_file_path)).to be(true)
          expect(File.size(merged_file_path)).to be_positive

          # Verify it's a valid PDF by loading it with CombinePDF
          expect { CombinePDF.load(merged_file_path) }.not_to raise_error
        end
      end
    end

    context 'with partial rule enablement' do
      before do
        # Only enable Medicare card merging
        allow(Flipper).to receive(:enabled?).with('champva_docmerge_10_7959c_medicare', current_user).and_return(true)
        allow(Flipper).to receive(:enabled?).with('champva_docmerge_10_7959c_ohi', current_user).and_return(false)
      end

      it 'only merges enabled rules and leaves non-mergeable documents unchanged' do
        result = merger.process

        # Should have 3 files: 1 merged Medicare card + 2 individual non-mergeable documents
        expect(result[:merged_file_paths].length).to eq(3)
        expect(result[:updated_attachment_ids]).to include('Medicare card')
        expect(result[:updated_attachment_ids]).to include('EOB')
        expect(result[:updated_attachment_ids]).to include('Birth Certificate')

        # Verify non-mergeable documents are original files (not merged)
        expect(result[:merged_file_paths]).to include(eob_document)
        expect(result[:merged_file_paths]).to include(other_document)
      end
    end

    context 'with documents that should not be merged' do
      let(:file_paths) { [eob_document, other_document] }
      let(:attachment_ids) { ['EOB', 'Birth Certificate'] }

      before do
        # Enable all merge rules but test with non-mergeable documents
        allow(Flipper).to receive(:enabled?).with('champva_docmerge_10_7959c_medicare', current_user).and_return(true)
        allow(Flipper).to receive(:enabled?).with('champva_docmerge_10_7959c_ohi', current_user).and_return(true)
      end

      it 'does not merge documents that do not match any merge rules' do
        result = merger.process

        # Should return original files unchanged
        expect(result[:merged_file_paths]).to eq([eob_document, other_document])
        expect(result[:updated_attachment_ids]).to eq(['EOB', 'Birth Certificate'])

        # No merged files should be created
        result[:merged_file_paths].each do |file_path|
          expect(File.basename(file_path)).not_to include('_merged.pdf')
        end
      end
    end
  end

  describe 'nil current_user behavior' do
    let(:nil_user_merger) do
      described_class.new(form_id, file_paths, attachment_ids, nil, { uuid: })
    end

    before do
      allow_any_instance_of(IvcChampva::Monitor).to receive(:track_merge_error)
    end

    context 'when global toggle is enabled' do
      before do
        # Mock all potential Flipper calls for nil user
        allow(Flipper).to receive(:enabled?).and_return(false) # Default to false
        allow(Flipper).to receive(:enabled?).with(:champva_document_merging, nil).and_return(true)
        allow(Flipper).to receive(:enabled?).with('champva_docmerge_10_7959c_medicare', nil).and_return(true)
      end

      it 'processes merging when global toggle allows it' do
        result = nil_user_merger.process

        # Should merge Medicare cards even with nil user due to global toggle
        expect(result[:merged_file_paths].length).to eq(3)
        expect(result[:updated_attachment_ids]).to contain_exactly('Medicare card', 'EOB', 'Birth Certificate')

        # Verify merged file exists
        merged_file = result[:merged_file_paths].find { |path| File.basename(path).include?('_merged.pdf') }
        expect(merged_file).not_to be_nil
        expect(File.exist?(merged_file)).to be(true)
      end
    end

    context 'when global toggle is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_return(false) # All toggles disabled
      end

      it 'skips merging when global toggle disallows it' do
        result = nil_user_merger.process

        # Should return original files unchanged
        expect(result[:merged_file_paths]).to eq(file_paths)
        expect(result[:updated_attachment_ids]).to eq(attachment_ids)

        # No merged files should be created
        result[:merged_file_paths].each do |file_path|
          expect(File.basename(file_path)).not_to include('_merged.pdf')
        end
      end
    end
  end

  describe 'batch processing with multiple card pairs' do
    let(:file_paths) do
      [
        medicare_front, medicare_back, # First Medicare card pair
        medicare_front, medicare_back, # Second Medicare card pair
        medicare_front, medicare_back  # Third Medicare card pair
      ]
    end
    let(:attachment_ids) do
      [
        'Front of Medicare card', 'Back of Medicare card',
        'Front of Medicare card', 'Back of Medicare card',
        'Front of Medicare card', 'Back of Medicare card'
      ]
    end

    before do
      allow(Flipper).to receive(:enabled?).with('champva_docmerge_10_7959c_medicare', current_user).and_return(true)
    end

    it 'processes all card pairs in batches of 2' do
      result = merger.process

      # Should create 3 separate merged Medicare card files
      expect(result[:merged_file_paths].length).to eq(3)
      expect(result[:updated_attachment_ids]).to eq(['Medicare card', 'Medicare card', 'Medicare card'])

      # Verify all merged files exist and are unique
      expect(result[:merged_file_paths].uniq.length).to eq(3)
      result[:merged_file_paths].each do |file_path|
        expect(File.exist?(file_path)).to be(true)
      end
    end
  end

  describe 'error handling' do
    let(:invalid_file_paths) { ['/nonexistent/file1.pdf', '/nonexistent/file2.pdf'] }
    let(:invalid_attachment_ids) { ['Front of Medicare card', 'Back of Medicare card'] }
    let(:invalid_merger) do
      described_class.new(form_id, invalid_file_paths, invalid_attachment_ids, current_user, { uuid: })
    end

    before do
      allow(Flipper).to receive(:enabled?).with('champva_docmerge_10_7959c_medicare', current_user).and_return(true)
      allow_any_instance_of(IvcChampva::Monitor).to receive(:track_merge_error).and_return(true)
    end

    it 'handles merge failures gracefully and returns original files' do
      result = invalid_merger.process

      # Should fallback to original files when merge fails
      expect(result[:merged_file_paths]).to eq(invalid_file_paths)
      expect(result[:updated_attachment_ids]).to eq(invalid_attachment_ids)
    end

    it 'returns individual files when merge_file_chunk fails' do
      # Mock PdfCombiner to raise an error during merge
      allow(IvcChampva::PdfCombiner).to receive(:combine).and_raise(StandardError.new('PDF merge failed'))

      result = merger.process

      # Should return all original files individually instead of losing them
      expect(result[:merged_file_paths].length).to eq(4) # All original files returned
      expect(result[:updated_attachment_ids]).to contain_exactly('Front of Medicare card', 'Back of Medicare card',
                                                                 'EOB', 'Birth Certificate')

      # All returned files should be the original files (no merged files created)
      expect(result[:merged_file_paths]).to match_array(file_paths)
    end
  end

  describe 'size-based chunking' do
    let(:small_size_limit) { 1.kilobyte } # Very small limit to force chunking
    let(:merger_with_limit) do
      described_class.new(form_id, file_paths, attachment_ids, current_user,
                          { uuid:, size_limit: small_size_limit })
    end

    before do
      allow(Flipper).to receive(:enabled?).with('champva_docmerge_10_7959c_medicare', current_user).and_return(true)
      allow(Flipper).to receive(:enabled?).with('champva_docmerge_10_7959c_ohi', current_user).and_return(true)
    end

    it 'creates multiple chunks when size limit is exceeded' do
      result = merger_with_limit.process

      # With very small size limit, should create more merged files than normal
      expect(result[:merged_file_paths].length).to be >= 2
      expect(result[:updated_attachment_ids].length).to be >= 2

      # All files should still be valid
      result[:merged_file_paths].each do |file_path|
        expect(File.exist?(file_path)).to be(true)
      end
    end
  end
end
