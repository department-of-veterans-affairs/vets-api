# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/benefits_intake/lighthouse_submission'
require 'benefits_intake_service/service'

RSpec.describe DependentsBenefits::BenefitsIntake::LighthouseSubmission do
  subject(:submission) { described_class.new(saved_claim, user_data, proc_id) }

  let(:saved_claim) { build(:dependency_claim) }
  let(:user_data) do
    {
      'veteran_information' => {
        'full_name' => {
          'first' => 'Mark',
          'last' => 'Webb'
        },
        'va_file_number' => '796104437',
        'ssn' => '796104437'
      }
    }
  end
  let(:proc_id) { 'test-proc-id-123' }
  let(:lighthouse_service) { instance_double(BenefitsIntakeService::Service) }
  let(:uuid) { SecureRandom.uuid }

  describe '#initialize' do
    it 'sets the saved_claim' do
      expect(submission.saved_claim).to eq(saved_claim)
    end

    it 'sets the user_data' do
      expect(submission.user_data).to eq(user_data)
    end

    it 'sets the proc_id' do
      expect(submission.proc_id).to eq(proc_id)
    end

    it 'initializes attachment_paths as empty array' do
      expect(submission.attachment_paths).to eq([])
    end

    it 'initializes form_path as nil' do
      expect(submission.form_path).to be_nil
    end

    it 'initializes uuid as nil' do
      expect(submission.uuid).to be_nil
    end

    context 'when proc_id is not provided' do
      subject(:submission) { described_class.new(saved_claim, user_data) }

      it 'sets proc_id to nil' do
        expect(submission.proc_id).to be_nil
      end
    end
  end

  describe '#initialize_service' do
    before do
      allow(BenefitsIntakeService::Service).to receive(:new)
        .with(with_upload_location: true)
        .and_return(lighthouse_service)
      allow(lighthouse_service).to receive(:uuid).and_return(uuid)
    end

    it 'creates a new BenefitsIntakeService with upload location' do
      submission.initialize_service

      expect(BenefitsIntakeService::Service).to have_received(:new)
        .with(with_upload_location: true)
    end

    it 'sets the lighthouse_service instance variable' do
      submission.initialize_service

      expect(submission.lighthouse_service).to eq(lighthouse_service)
    end

    it 'sets the uuid from the lighthouse service' do
      submission.initialize_service

      expect(submission.uuid).to eq(uuid)
    end
  end

  describe '#prepare_submission' do
    let(:claim_processor) { instance_double(DependentsBenefits::ClaimProcessor) }
    let(:child_claim) { instance_double(DependentsBenefits::AddRemoveDependent) }
    let(:pdf_path) { 'tmp/test.pdf' }

    before do
      allow(saved_claim).to receive_messages(
        add_veteran_info: nil,
        persistent_attachments: []
      )
      # Stub dependencies used by get_files_from_claim instead of stubbing the method itself
      allow(DependentsBenefits::ClaimProcessor).to receive(:new).with(saved_claim.id).and_return(claim_processor)
      allow(claim_processor).to receive(:collect_child_claims).and_return([child_claim])
      allow(child_claim).to receive_messages(
        add_veteran_info: nil,
        to_pdf: pdf_path,
        created_at: Time.zone.now,
        form_id: '21-686C'
      )
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(
        instance_double(PDFUtilities::DatestampPdf, run: pdf_path)
      )
    end

    it 'adds veteran info to the saved claim' do
      submission.prepare_submission

      expect(saved_claim).to have_received(:add_veteran_info).with(user_data)
    end

    it 'collects files from the claim' do
      submission.prepare_submission

      expect(claim_processor).to have_received(:collect_child_claims)
    end
  end

  describe '#get_files_from_claim (private)' do
    let(:claim_processor) { instance_double(DependentsBenefits::ClaimProcessor) }
    let(:form686c_claim) { instance_double(DependentsBenefits::AddRemoveDependent) }
    let(:form674_claim) { instance_double(DependentsBenefits::SchoolAttendanceApproval) }
    let(:persistent_attachment) { instance_double(PersistentAttachment) }
    let(:pdf_path686c) { 'tmp/686c.pdf' }
    let(:pdf_path674) { 'tmp/674.pdf' }
    let(:pdf_path_attachment) { 'tmp/attachment.pdf' }
    let(:stamped_path686c) { 'tmp/stamped_686c.pdf' }
    let(:stamped_path674) { 'tmp/stamped_674.pdf' }
    let(:stamped_path_attachment) { 'tmp/stamped_attachment.pdf' }

    before do
      allow(DependentsBenefits::ClaimProcessor).to receive(:new).with(saved_claim.id).and_return(claim_processor)
      allow(saved_claim).to receive(:persistent_attachments).and_return([])
      # Stub PDFUtilities::DatestampPdf to return stamped paths
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_call_original
    end

    context 'when there are 674 forms and persistent attachments' do
      before do
        allow(claim_processor).to receive(:collect_child_claims).and_return([form686c_claim, form674_claim])
        allow(form686c_claim).to receive_messages(
          add_veteran_info: nil,
          to_pdf: pdf_path686c,
          created_at: Time.zone.now,
          form_id: DependentsBenefits::ADD_REMOVE_DEPENDENT
        )
        allow(form674_claim).to receive_messages(
          add_veteran_info: nil,
          to_pdf: pdf_path674,
          created_at: Time.zone.now,
          form_id: '21-674'
        )
        allow(persistent_attachment).to receive_messages(
          to_pdf: pdf_path_attachment
        )
        allow(saved_claim).to receive(:persistent_attachments).and_return([persistent_attachment])
        # Stub PDFUtilities::DatestampPdf to return appropriate stamped paths
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path686c).and_return(
          instance_double(PDFUtilities::DatestampPdf, run: stamped_path686c)
        )
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path674).and_return(
          instance_double(PDFUtilities::DatestampPdf, run: stamped_path674)
        )
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path_attachment).and_return(
          instance_double(PDFUtilities::DatestampPdf, run: stamped_path_attachment)
        )
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(stamped_path686c).and_return(
          instance_double(PDFUtilities::DatestampPdf, run: stamped_path686c)
        )
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(stamped_path674).and_return(
          instance_double(PDFUtilities::DatestampPdf, run: stamped_path674)
        )
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(stamped_path_attachment).and_return(
          instance_double(PDFUtilities::DatestampPdf, run: stamped_path_attachment)
        )
      end

      it 'adds 674 form to form674_paths array' do
        submission.send(:get_files_from_claim)

        # The 674 should be added to attachment_paths since 686c is the main form
        expect(submission.attachment_paths).to include(stamped_path674)
      end

      it 'processes persistent attachments with saved_claim.created_at' do
        submission.send(:get_files_from_claim)

        # Verify attachment was processed and included
        expect(submission.attachment_paths).to include(stamped_path_attachment)
      end

      it 'prepends 674 forms before persistent attachments' do
        submission.send(:get_files_from_claim)

        expect(submission.attachment_paths).to eq([stamped_path674, stamped_path_attachment])
      end
    end

    context 'when 686c is present' do
      before do
        allow(claim_processor).to receive(:collect_child_claims).and_return([form686c_claim])
        allow(form686c_claim).to receive_messages(
          add_veteran_info: nil,
          to_pdf: pdf_path686c,
          created_at: Time.zone.now,
          form_id: DependentsBenefits::ADD_REMOVE_DEPENDENT
        )
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path686c).and_return(
          instance_double(PDFUtilities::DatestampPdf, run: stamped_path686c)
        )
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(stamped_path686c).and_return(
          instance_double(PDFUtilities::DatestampPdf, run: stamped_path686c)
        )
      end

      it 'sets 686c as the main form_path' do
        submission.send(:get_files_from_claim)

        expect(submission.form_path).to eq(stamped_path686c)
      end
    end

    context 'when only 674 form is present' do
      before do
        allow(claim_processor).to receive(:collect_child_claims).and_return([form674_claim])
        allow(form674_claim).to receive_messages(
          add_veteran_info: nil,
          to_pdf: pdf_path674,
          created_at: Time.zone.now,
          form_id: '21-674'
        )
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path674).and_return(
          instance_double(PDFUtilities::DatestampPdf, run: stamped_path674)
        )
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(stamped_path674).and_return(
          instance_double(PDFUtilities::DatestampPdf, run: stamped_path674)
        )
      end

      it 'uses first 674 as main form_path when 686c is not present' do
        submission.send(:get_files_from_claim)

        expect(submission.form_path).to eq(stamped_path674)
      end

      it 'does not include the main 674 in attachment_paths' do
        submission.send(:get_files_from_claim)

        expect(submission.attachment_paths).not_to include(stamped_path674)
      end
    end

    context 'when no forms are generated' do
      before do
        allow(claim_processor).to receive(:collect_child_claims).and_return([])
      end

      it 'raises an error' do
        expect do
          submission.send(:get_files_from_claim)
        end.to raise_error(RuntimeError,
                           'No main form PDF generated for Lighthouse submission')
      end
    end
  end

  describe '#upload_to_lh' do
    let(:form_path) { 'tmp/test_form.pdf' }
    let(:attachment_paths) { ['tmp/attachment1.pdf', 'tmp/attachment2.pdf'] }
    let(:saved_claim) do
      claim = build(:dependency_claim)
      form = claim.parsed_form
      form['dependents_application']['veteran_contact_information']['veteran_address']['postal_code'] = '21122'
      claim.form = form.to_json
      claim
    end
    let(:upload_response) { { status: 'success', uuid: } }

    before do
      submission.instance_variable_set(:@form_path, form_path)
      submission.instance_variable_set(:@attachment_paths, attachment_paths)
      submission.instance_variable_set(:@lighthouse_service, lighthouse_service)
      allow(lighthouse_service).to receive(:upload_form).and_return(upload_response)
    end

    it 'uploads form with main document, attachments, and metadata' do
      submission.upload_to_lh

      expect(lighthouse_service).to have_received(:upload_form).with(
        main_document: { file: form_path, file_name: 'test_form.pdf' },
        attachments: [
          { file: 'tmp/attachment1.pdf', file_name: 'attachment1.pdf' },
          { file: 'tmp/attachment2.pdf', file_name: 'attachment2.pdf' }
        ],
        form_metadata: hash_including(
          veteran_first_name: 'Mark',
          veteran_last_name: 'Webb',
          file_number: '796104437',
          zip: '21122',
          doc_type: '686C-674',
          source: 'va.gov backup dependent claim submission',
          business_line: 'CMP'
        )
      )
    end

    it 'returns the lighthouse service response' do
      result = submission.upload_to_lh

      expect(result).to eq(upload_response)
    end
  end

  describe '#cleanup_file_paths' do
    let(:form_path) { 'tmp/test_form.pdf' }
    let(:attachment_paths) { ['tmp/attachment1.pdf', 'tmp/attachment2.pdf'] }

    before do
      submission.instance_variable_set(:@form_path, form_path)
      submission.instance_variable_set(:@attachment_paths, attachment_paths)
      allow(Common::FileHelpers).to receive(:delete_file_if_exists)
    end

    it 'deletes the form file' do
      submission.cleanup_file_paths

      expect(Common::FileHelpers).to have_received(:delete_file_if_exists).with(form_path)
    end

    it 'deletes all attachment files' do
      submission.cleanup_file_paths

      expect(Common::FileHelpers).to have_received(:delete_file_if_exists).with('tmp/attachment1.pdf')
      expect(Common::FileHelpers).to have_received(:delete_file_if_exists).with('tmp/attachment2.pdf')
    end

    context 'when attachment_paths is empty' do
      before do
        submission.instance_variable_set(:@attachment_paths, [])
      end

      it 'does not raise error' do
        expect { submission.cleanup_file_paths }.not_to raise_error
      end
    end
  end

  describe '#process_pdf' do
    let(:pdf_path) { 'tmp/test.pdf' }
    let(:timestamp) { Time.zone.now }
    let(:datestamp_pdf_instance1) { instance_double(PDFUtilities::DatestampPdf) }
    let(:datestamp_pdf_instance2) { instance_double(PDFUtilities::DatestampPdf) }
    let(:stamped_path1) { 'tmp/stamped1.pdf' }
    let(:stamped_path2) { 'tmp/stamped2.pdf' }

    before do
      # Stub any PDFUtilities::DatestampPdf calls to avoid real PDF operations
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_call_original
      allow(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path).and_return(datestamp_pdf_instance1)
      allow(PDFUtilities::DatestampPdf).to receive(:new).with(stamped_path1).and_return(datestamp_pdf_instance2)
      allow(datestamp_pdf_instance1).to receive(:run).and_return(stamped_path1)
      allow(datestamp_pdf_instance2).to receive(:run).and_return(stamped_path2)
    end

    context 'without form_id' do
      it 'stamps PDF with VA.GOV text' do
        submission.process_pdf(pdf_path, timestamp)

        expect(datestamp_pdf_instance1).to have_received(:run).with(
          text: 'VA.GOV',
          x: 5,
          y: 5,
          timestamp:,
          template: DependentsBenefits::PDF_PATH_21_686C
        )
      end

      it 'stamps PDF with FDC review notice' do
        submission.process_pdf(pdf_path, timestamp)

        expect(datestamp_pdf_instance2).to have_received(:run).with(
          text: 'FDC Reviewed - va.gov Submission',
          x: 400,
          y: 770,
          text_only: true,
          template: DependentsBenefits::PDF_PATH_21_686C
        )
      end

      it 'returns the stamped path' do
        result = submission.process_pdf(pdf_path, timestamp)

        expect(result).to eq(stamped_path2)
      end
    end

    context 'with form_id 686C-674' do
      let(:form_id) { '686C-674' }
      let(:datestamp_pdf_instance3) { instance_double(PDFUtilities::DatestampPdf) }
      let(:stamped_path3) { 'tmp/stamped3.pdf' }

      before do
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(stamped_path2).and_return(datestamp_pdf_instance3)
        allow(datestamp_pdf_instance3).to receive(:run).and_return(stamped_path3)
      end

      it 'stamps PDF with form-specific submission text on page 6' do
        submission.process_pdf(pdf_path, timestamp, form_id)

        expect(datestamp_pdf_instance3).to have_received(:run).with(
          text: 'Application Submitted on va.gov',
          x: 400,
          y: 675,
          text_only: true,
          timestamp:,
          page_number: 6,
          template: "#{DependentsBenefits::PDF_PATH_BASE}/#{form_id}.pdf",
          multistamp: true
        )
      end

      it 'returns the final stamped path' do
        result = submission.process_pdf(pdf_path, timestamp, form_id)

        expect(result).to eq(stamped_path3)
      end
    end

    context 'with form_id 686C-674-V2' do
      let(:form_id) { '686C-674-V2' }
      let(:datestamp_pdf_instance3) { instance_double(PDFUtilities::DatestampPdf) }
      let(:stamped_path3) { 'tmp/stamped3.pdf' }

      before do
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(stamped_path2).and_return(datestamp_pdf_instance3)
        allow(datestamp_pdf_instance3).to receive(:run).and_return(stamped_path3)
      end

      it 'stamps PDF on page 6 for combined form' do
        submission.process_pdf(pdf_path, timestamp, form_id)

        expect(datestamp_pdf_instance3).to have_received(:run).with(
          hash_including(page_number: 6)
        )
      end
    end

    context 'with other form_id' do
      let(:form_id) { '21-686C' }
      let(:datestamp_pdf_instance3) { instance_double(PDFUtilities::DatestampPdf) }
      let(:stamped_path3) { 'tmp/stamped3.pdf' }

      before do
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(stamped_path2).and_return(datestamp_pdf_instance3)
        allow(datestamp_pdf_instance3).to receive(:run).and_return(stamped_path3)
      end

      it 'stamps PDF on page 0 for other forms' do
        submission.process_pdf(pdf_path, timestamp, form_id)

        expect(datestamp_pdf_instance3).to have_received(:run).with(
          hash_including(page_number: 0)
        )
      end
    end
  end

  describe '#generate_metadata_lh' do
    let(:saved_claim) do
      claim = build(:dependency_claim)
      form = claim.parsed_form
      # Factory uses zip_code, but code looks for postal_code - set both
      form['dependents_application']['veteran_contact_information']['veteran_address']['postal_code'] = '21122'
      claim.form = form.to_json
      claim
    end
    let(:metadata) { submission.send(:generate_metadata_lh) }

    it 'includes veteran first name' do
      expect(metadata[:veteran_first_name]).to eq('Mark')
    end

    it 'includes veteran last name' do
      expect(metadata[:veteran_last_name]).to eq('Webb')
    end

    it 'includes file number' do
      expect(metadata[:file_number]).to eq('796104437')
    end

    it 'includes zip code' do
      expect(metadata[:zip]).to eq('21122')
    end

    it 'includes doc type' do
      expect(metadata[:doc_type]).to eq('686C-674')
    end

    it 'includes claim date' do
      expect(metadata[:claim_date]).to eq(saved_claim.created_at)
    end

    it 'includes source' do
      expect(metadata[:source]).to eq('va.gov backup dependent claim submission')
    end

    it 'includes business line' do
      expect(metadata[:business_line]).to eq('CMP')
    end
  end

  describe '#user_zipcode (private)' do
    let(:saved_claim) do
      claim = build(:dependency_claim)
      form = claim.parsed_form
      # Factory uses zip_code, but code looks for postal_code - set it explicitly
      form['dependents_application']['veteran_contact_information']['veteran_address']['postal_code'] = '21122'
      claim.form = form.to_json
      claim
    end

    it 'returns zip code from USA address' do
      zipcode = submission.send(:user_zipcode)

      expect(zipcode).to eq('21122')
    end

    context 'when address is not USA' do
      let(:saved_claim) do
        claim = build(:dependency_claim)
        form = claim.parsed_form
        form['dependents_application']['veteran_contact_information']['veteran_address']['country_name'] = 'Canada'
        claim.form = form.to_json
        claim
      end

      it 'returns FOREIGN_POSTALCODE' do
        zipcode = submission.send(:user_zipcode)

        expect(zipcode).to eq(described_class::FOREIGN_POSTALCODE)
      end
    end

    context 'when postal code is missing' do
      let(:saved_claim) do
        claim = build(:dependency_claim)
        form = claim.parsed_form
        form['dependents_application']['veteran_contact_information']['veteran_address'].delete('postal_code')
        form['dependents_application']['veteran_contact_information']['veteran_address'].delete('zip_code')
        claim.form = form.to_json
        claim
      end

      it 'returns FOREIGN_POSTALCODE' do
        zipcode = submission.send(:user_zipcode)

        expect(zipcode).to eq(described_class::FOREIGN_POSTALCODE)
      end
    end

    context 'when address is not present' do
      let(:saved_claim) do
        claim = build(:dependency_claim)
        form = claim.parsed_form
        form['dependents_application']['veteran_contact_information']['veteran_address'] = nil
        claim.form = form.to_json
        claim
      end

      it 'returns FOREIGN_POSTALCODE' do
        zipcode = submission.send(:user_zipcode)

        expect(zipcode).to eq(described_class::FOREIGN_POSTALCODE)
      end
    end
  end

  describe '#split_file_and_path (private)' do
    it 'splits path into file and file_name' do
      path = '/tmp/folder/test_file.pdf'
      result = submission.send(:split_file_and_path, path)

      expect(result).to eq({ file: path, file_name: 'test_file.pdf' })
    end

    it 'handles simple filenames' do
      path = 'document.pdf'
      result = submission.send(:split_file_and_path, path)

      expect(result).to eq({ file: path, file_name: 'document.pdf' })
    end
  end

  describe '#get_hash_and_pages (private)' do
    let(:file_path) { 'tmp/test_file.pdf' }
    let(:pdf_metadata) { instance_double(PdfInfo::Metadata, pages: 5) }
    let(:expected_hash) { 'a' * 64 } # Mock SHA256 hash (64 hex characters)

    before do
      allow(Digest::SHA256).to receive(:file).with(file_path).and_return(
        instance_double(Digest::SHA256, hexdigest: expected_hash)
      )
      allow(PdfInfo::Metadata).to receive(:read).with(file_path).and_return(pdf_metadata)
    end

    it 'returns hash with SHA256 digest' do
      result = submission.send(:get_hash_and_pages, file_path)

      expect(result[:hash]).to eq(expected_hash)
    end

    it 'returns hash with page count' do
      result = submission.send(:get_hash_and_pages, file_path)

      expect(result[:pages]).to eq(5)
    end

    it 'calls Digest::SHA256.file with the file path' do
      submission.send(:get_hash_and_pages, file_path)

      expect(Digest::SHA256).to have_received(:file).with(file_path)
    end

    it 'calls PdfInfo::Metadata.read with the file path' do
      submission.send(:get_hash_and_pages, file_path)

      expect(PdfInfo::Metadata).to have_received(:read).with(file_path)
    end

    it 'returns a hash with both keys' do
      result = submission.send(:get_hash_and_pages, file_path)

      expect(result.keys).to contain_exactly(:hash, :pages)
    end
  end

  describe '#template_for_form (private)' do
    it 'returns form-specific template when form_id provided' do
      template = submission.send(:template_for_form, '686C-674')

      expect(template).to eq("#{DependentsBenefits::PDF_PATH_BASE}/686C-674.pdf")
    end

    it 'returns default template when form_id is nil' do
      template = submission.send(:template_for_form, nil)

      expect(template).to eq(DependentsBenefits::PDF_PATH_21_686C)
    end

    it 'returns constructed path when form_id is blank string' do
      template = submission.send(:template_for_form, '')

      # Empty string is truthy in Ruby, so it constructs the path
      expect(template).to eq("#{DependentsBenefits::PDF_PATH_BASE}/.pdf")
    end
  end

  describe 'FOREIGN_POSTALCODE constant' do
    it 'is set to 00000' do
      expect(described_class::FOREIGN_POSTALCODE).to eq('00000')
    end
  end
end
