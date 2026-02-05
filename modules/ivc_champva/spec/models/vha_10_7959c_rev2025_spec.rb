# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA107959cRev2025 do
  let(:fixture_data) do
    JSON.parse(File.read('modules/ivc_champva/spec/fixtures/form_json/vha_10_7959c_rev2025.json'))
  end
  let(:form) { described_class.new(fixture_data) }
  let(:statsd_key) { described_class::STATS_KEY }

  before do
    allow(form).to receive_messages(get_attachments: [])
  end

  describe '#initialize' do
    it 'sets the form_id' do
      expect(form.form_id).to eq('vha_10_7959c_rev2025')
    end

    it 'generates a uuid' do
      expect(form.uuid).to be_present
    end

    context 'data transformation' do
      it 'flattens applicant data from applicants array to root level' do
        expect(form.data['applicant_name']).to eq({
                                                    'first' => 'Applicant',
                                                    'middle' => 'I',
                                                    'last' => 'Surname'
                                                  })
        expect(form.data['applicant_ssn']).to eq('234234234')
        expect(form.data['applicant_address']['postal_code']).to eq('12323')
      end

      it 'flattens health_insurance to applicant_primary_* fields' do
        expect(form.data['applicant_primary_provider']).to eq('Blue Cross Blue Shield')
        expect(form.data['applicant_primary_effective_date']).to eq('10-01-2024')
        expect(form.data['applicant_primary_expiration_date']).to eq('10-02-2024')
        expect(form.data['applicant_primary_through_employer']).to be(true)
        expect(form.data['applicant_primary_insurance_type']).to eq('medigap')
        expect(form.data['applicant_primary_eob']).to be(true)
        expect(form.data['primary_medigap_plan']).to eq('K')
        expect(form.data['primary_additional_comments']).to eq('Lorem')
      end

      it 'preserves medicare array at root level after transformation' do
        expect(form.data['medicare']).to be_an(Array)
        expect(form.data['medicare'].first['medicare_plan_type']).to eq('c')
      end

      it 'preserves form-level fields' do
        expect(form.data['statement_of_truth_signature']).to eq('Certifier Jones')
        expect(form.data['certification_date']).to eq('01-01-2010')
        expect(form.data['certifier_role']).to eq('other')
      end

      context 'applicant_email_address normalization' do
        context 'when certifier_role is not applicant' do
          it 'uses applicant_email for applicant_email_address' do
            expect(form.data['certifier_role']).to eq('other')
            expect(form.data['applicant_email_address']).to eq('applicant@email.gov')
          end
        end

        context 'when certifier_role is applicant' do
          let(:data_with_applicant_certifier) do
            fixture_data.deep_dup.tap do |d|
              d['certifier_role'] = 'applicant'
              d['certifier_email'] = 'certifier@email.gov'
            end
          end
          let(:form) { described_class.new(data_with_applicant_certifier) }

          it 'uses certifier_email for applicant_email_address' do
            expect(form.data['applicant_email_address']).to eq('certifier@email.gov')
          end
        end

        context 'when certifier_role is applicant but certifier_email is missing' do
          let(:data_with_applicant_certifier_no_email) do
            fixture_data.deep_dup.tap do |d|
              d['certifier_role'] = 'applicant'
              d.delete('certifier_email')
            end
          end
          let(:form) { described_class.new(data_with_applicant_certifier_no_email) }

          it 'falls back to nil when certifier_email is absent' do
            expect(form.data['applicant_email_address']).to be_nil
          end
        end

        context 'when applicant_email_address is already set' do
          let(:data_with_existing_email) do
            fixture_data.deep_dup.tap do |d|
              d['applicants'].first['applicant_email_address'] = 'existing@email.gov'
            end
          end
          let(:form) { described_class.new(data_with_existing_email) }

          it 'preserves existing applicant_email_address' do
            expect(form.data['applicant_email_address']).to eq('existing@email.gov')
          end
        end
      end

      it 'preserves form_number from frontend submission' do
        expect(form.data['form_number']).to eq('10-7959C')
      end

      context 'with pre-flattened data' do
        let(:pre_flattened_data) do
          {
            'applicant_name' => { 'first' => 'John', 'last' => 'Doe' },
            'applicant_ssn' => '123456789',
            'applicant_primary_provider' => 'Already Flattened Insurance',
            'form_number' => '10-7959C'
          }
        end
        let(:form) { described_class.new(pre_flattened_data) }

        it 'does not re-transform already flattened data' do
          expect(form.data['applicant_primary_provider']).to eq('Already Flattened Insurance')
          expect(form.data['applicant_name']['first']).to eq('John')
        end
      end

      context 'with two health insurance policies' do
        let(:data_with_two_policies) do
          fixture_data.deep_dup.tap do |d|
            d['applicants'].first['health_insurance'] << {
              'insurance_type' => 'ppo',
              'provider' => 'Secondary Insurance Co',
              'effective_date' => '01-01-2024',
              'expiration_date' => '12-31-2024',
              'through_employer' => false,
              'eob' => false,
              'medigap_plan' => nil,
              'additional_comments' => 'Secondary policy'
            }
          end
        end
        let(:form) { described_class.new(data_with_two_policies) }

        it 'flattens both policies to primary and secondary fields' do
          expect(form.data['applicant_primary_provider']).to eq('Blue Cross Blue Shield')
          expect(form.data['applicant_secondary_provider']).to eq('Secondary Insurance Co')
          expect(form.data['applicant_secondary_insurance_type']).to eq('ppo')
          expect(form.data['applicant_secondary_through_employer']).to be(false)
          expect(form.data['secondary_additional_comments']).to eq('Secondary policy')
        end
      end
    end
  end

  describe '#metadata' do
    context 'when champva_update_metadata_keys flipper is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(true)
      end

      it 'returns metadata with sponsor/beneficiary keys' do
        metadata = form.metadata

        expect(metadata).to include(
          'sponsorFirstName' => 'Applicant',
          'sponsorMiddleName' => 'I',
          'sponsorLastName' => 'Surname',
          'fileNumber' => '234234234',
          'zipCode' => '12323',
          'ssn_or_tin' => '234234234',
          'country' => 'USA',
          'source' => 'VA Platform Digital Forms',
          'docType' => '10-7959C',
          'businessLine' => 'CMP',
          'primaryContactEmail' => 'false',
          'beneficiaryEmail' => 'applicant@email.gov'
        )
      end
    end

    context 'when champva_update_metadata_keys flipper is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(false)
      end

      it 'returns metadata with veteran/applicant keys' do
        metadata = form.metadata

        expect(metadata).to include(
          'veteranFirstName' => 'Applicant',
          'veteranMiddleName' => 'I',
          'veteranLastName' => 'Surname',
          'fileNumber' => '234234234',
          'zipCode' => '12323',
          'ssn_or_tin' => '234234234',
          'country' => 'USA',
          'source' => 'VA Platform Digital Forms',
          'docType' => '10-7959C',
          'businessLine' => 'CMP',
          'primaryContactEmail' => 'false',
          'applicantEmail' => 'applicant@email.gov'
        )
      end
    end
  end

  describe '#desired_stamps' do
    it 'returns signature stamp for the form' do
      stamps = form.desired_stamps

      expect(stamps).to be_an(Array)
      expect(stamps.length).to eq(1)
      expect(stamps.first).to include(
        coords: [170, 65],
        text: 'Certifier Jones',
        page: 0
      )
    end

    context 'when data is nil' do
      let(:form) { described_class.new(nil) }

      it 'returns empty array' do
        expect(form.desired_stamps).to eq([])
      end
    end
  end

  describe '#track_user_identity' do
    it 'increments StatsD and logs user identity' do
      expect(StatsD).to receive(:increment).with("#{statsd_key}.other")
      expect(Rails.logger).to receive(:info).with(
        'IVC ChampVA Forms - 10-7959C-REV2025 Submission User Identity',
        identity: 'other'
      )

      form.track_user_identity
    end
  end

  describe '#track_current_user_loa' do
    context 'when current loa is present' do
      it 'increments StatsD with user loa' do
        mock_user = double(loa: double)
        allow(mock_user.loa).to receive(:[]).with(:current).and_return(3)

        expect(StatsD).to receive(:increment).with("#{statsd_key}.3")
        expect(Rails.logger).to receive(:info).with(
          'IVC ChampVA Forms - 10-7959C-REV2025 Current User LOA',
          current_user_loa: 3
        )

        form.track_current_user_loa(mock_user)
      end
    end

    context 'when current loa is missing' do
      it 'increments StatsD with loa 0' do
        mock_user = double(loa: double)
        allow(mock_user.loa).to receive(:[]).with(:current).and_return(nil)

        expect(StatsD).to receive(:increment).with("#{statsd_key}.0")
        expect(Rails.logger).to receive(:info).with(
          'IVC ChampVA Forms - 10-7959C-REV2025 Current User LOA',
          current_user_loa: 0
        )

        form.track_current_user_loa(mock_user)
      end
    end
  end

  describe '#track_email_usage' do
    context 'when email is used' do
      let(:data_with_email) do
        fixture_data.deep_dup.tap do |d|
          d['primary_contact_info']['email'] = 'test@example.com'
        end
      end
      let(:form) { described_class.new(data_with_email) }

      it 'increments StatsD with yes' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.yes")
        expect(Rails.logger).to receive(:info).with(
          'IVC ChampVA Forms - 10-7959C-REV2025 Email Used',
          email_used: 'yes'
        )

        form.track_email_usage
      end
    end

    context 'when email is not used' do
      it 'increments StatsD with no' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.no")
        expect(Rails.logger).to receive(:info).with(
          'IVC ChampVA Forms - 10-7959C-REV2025 Email Used',
          email_used: 'no'
        )

        form.track_email_usage
      end
    end
  end

  describe '#track_delegate_form' do
    it 'increments StatsD and logs delegate form' do
      expect(StatsD).to receive(:increment).with("#{statsd_key}.delegate_form.vha_10_10d")
      expect(Rails.logger).to receive(:info).with(
        'IVC ChampVA Forms - 10-7959C-REV2025 Delegate Form',
        parent_form_id: 'vha_10_10d'
      )

      form.track_delegate_form('vha_10_10d')
    end
  end

  describe '#method_missing' do
    it 'returns method name and arguments' do
      result = form.some_missing_method('arg1', 'arg2')

      expect(result).to eq({ method: :some_missing_method, args: %w[arg1 arg2] })
    end
  end

  describe '#handle_attachments' do
    it 'returns file path in array' do
      file_name = "#{form.uuid}_vha_10_7959c_rev2025-tmp.pdf"
      allow(File).to receive(:rename)

      result = form.handle_attachments(file_name)

      expect(result).to eq([file_name])
    end
  end

  it 'is not past OMB expiration date' do
    omb_expiration_date = Date.strptime('12312027', '%m%d%Y')
    error_message = <<~MSG
      If this test is failing it likely means the form 10-7959C-REV2025 PDF has reached
      OMB expiration date. Please see ivc_champva module README for details on updating the PDF file.
    MSG

    expect(omb_expiration_date.past?).to be(false), error_message
  end
end
