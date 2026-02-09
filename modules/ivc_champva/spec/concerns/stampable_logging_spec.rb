# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StampableLogging do
  before do
    allow(Flipper).to receive(:enabled?).with(:champva_stamper_logging).and_return(true)
  end

  describe 'VHA1010d logging' do
    let(:fixture_path) { Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json') }
    let(:fixture_data) { JSON.parse(fixture_path.read) }

    context 'when veteran country is missing' do
      let(:data_without_veteran_country) do
        fixture_data.merge(
          'veteran' => fixture_data['veteran'].merge('address' => {}),
          'form_number' => '10-10D-EXTENDED'
        )
      end
      let(:form_without_veteran_country) { IvcChampva::VHA1010d.new(data_without_veteran_country) }

      it 'logs missing veteran country data' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA1010d Missing stamp data for veteran_country/)
            .and(matching(/form_number: 10-10D-EXTENDED/))
            .and(matching(/is_deceased: /))
            .and(matching(/certifier_role: /))
        )

        form_without_veteran_country.desired_stamps
      end
    end

    context 'when first applicant country is missing' do
      let(:data_without_applicant_country) do
        fixture_data.merge(
          'applicants' => [{ 'applicant_address' => {} }],
          'form_number' => '10-10D'
        )
      end
      let(:form_without_applicant_country) { IvcChampva::VHA1010d.new(data_without_applicant_country) }

      it 'logs missing first applicant country data' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA1010d Missing stamp data for first_applicant_country/)
            .and(matching(/form_number: 10-10D/))
        )

        form_without_applicant_country.desired_stamps
      end
    end

    context 'when additional applicant country is missing' do
      let(:data_with_missing_applicant_country) do
        fixture_data.merge(
          'applicants' => [
            { 'applicant_address' => { 'country' => 'USA' } },
            { 'applicant_address' => {} }
          ]
        )
      end
      let(:form_with_missing_applicant_country) { IvcChampva::VHA1010d.new(data_with_missing_applicant_country) }

      it 'logs missing applicant country data for specific applicant' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA1010d Missing stamp data for applicant_1_country/)
        )

        form_with_missing_applicant_country.desired_stamps
      end
    end

    context 'when logging is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_stamper_logging).and_return(false)
      end

      let(:data_without_veteran_country) do
        fixture_data.merge('veteran' => fixture_data['veteran'].merge('address' => {}))
      end
      let(:form_without_veteran_country) { IvcChampva::VHA1010d.new(data_without_veteran_country) }

      it 'does not log when feature flag is disabled' do
        expect(Rails.logger).not_to receive(:info)

        form_without_veteran_country.desired_stamps
      end
    end
  end

  describe 'VHA1010d2027 logging' do
    let(:fixture_path) { Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json') }
    let(:fixture_data) { JSON.parse(fixture_path.read) }

    context 'when veteran country is missing' do
      let(:data_without_veteran_country) do
        fixture_data.merge(
          'veteran' => fixture_data['veteran'].merge('address' => {}),
          'form_number' => '10-10D-2027'
        )
      end
      let(:form_without_veteran_country) { IvcChampva::VHA1010d2027.new(data_without_veteran_country) }

      it 'logs missing veteran country data' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA1010d2027 Missing stamp data for veteran_country/)
            .and(matching(/form_number: 10-10D-2027/))
            .and(matching(/is_deceased: /))
            .and(matching(/certifier_role: /))
        )

        form_without_veteran_country.desired_stamps
      end
    end

    context 'when first applicant country is missing' do
      let(:data_without_applicant_country) do
        fixture_data.merge(
          'applicants' => [{ 'applicant_address' => {} }],
          'form_number' => '10-10D-2027'
        )
      end
      let(:form_without_applicant_country) { IvcChampva::VHA1010d2027.new(data_without_applicant_country) }

      it 'logs missing first applicant country data' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA1010d2027 Missing stamp data for first_applicant_country/)
            .and(matching(/form_number: 10-10D-2027/))
        )

        form_without_applicant_country.desired_stamps
      end
    end

    context 'when additional applicant country is missing' do
      let(:data_with_missing_applicant_country) do
        fixture_data.merge(
          'applicants' => [
            { 'applicant_address' => { 'country' => 'USA' } },
            { 'applicant_address' => {} }
          ]
        )
      end
      let(:form_with_missing_applicant_country) { IvcChampva::VHA1010d2027.new(data_with_missing_applicant_country) }

      it 'logs missing applicant country data for specific applicant' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA1010d2027 Missing stamp data for applicant_1_country/)
        )

        form_with_missing_applicant_country.desired_stamps
      end
    end
  end

  describe 'VHA107959a logging' do
    context 'when statement_of_truth_signature is missing' do
      let(:data_without_signature) do
        {
          'primary_contact_info' => { 'name' => { 'first' => 'Test', 'last' => 'User' } },
          'form_number' => '10-7959A'
        }
      end
      let(:form_without_signature) { IvcChampva::VHA107959a.new(data_without_signature) }

      it 'logs missing signature data' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA107959a Missing stamp data for statement_of_truth_signature/)
            .and(matching(/form_number: 10-7959A/))
        )

        form_without_signature.desired_stamps
      end
    end

    context 'when statement_of_truth_signature is blank' do
      let(:data_with_blank_signature) do
        {
          'primary_contact_info' => { 'name' => { 'first' => 'Test', 'last' => 'User' } },
          'statement_of_truth_signature' => '',
          'form_number' => '10-7959A'
        }
      end
      let(:form_with_blank_signature) { IvcChampva::VHA107959a.new(data_with_blank_signature) }

      it 'logs missing signature data for blank value' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA107959a Missing stamp data for statement_of_truth_signature/)
            .and(matching(/form_number: 10-7959A/))
        )

        form_with_blank_signature.desired_stamps
      end
    end
  end

  describe 'VHA107959f1 logging' do
    context 'when statement_of_truth_signature is missing' do
      let(:data_without_signature) do
        {
          'primary_contact_info' => { 'name' => { 'first' => 'Test', 'last' => 'User' } },
          'form_number' => '10-7959F-1'
        }
      end
      let(:form_without_signature) { IvcChampva::VHA107959f1.new(data_without_signature) }

      it 'logs missing signature data' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA107959f1 Missing stamp data for statement_of_truth_signature/)
            .and(matching(/form_number: 10-7959F-1/))
        )

        form_without_signature.desired_stamps
      end
    end

    context 'when statement_of_truth_signature is blank' do
      let(:data_with_blank_signature) do
        {
          'primary_contact_info' => { 'name' => { 'first' => 'Test', 'last' => 'User' } },
          'statement_of_truth_signature' => '',
          'form_number' => '10-7959F-1'
        }
      end
      let(:form_with_blank_signature) { IvcChampva::VHA107959f1.new(data_with_blank_signature) }

      it 'logs missing signature data for blank value' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA107959f1 Missing stamp data for statement_of_truth_signature/)
            .and(matching(/form_number: 10-7959F-1/))
        )

        form_with_blank_signature.desired_stamps
      end
    end
  end

  describe 'VHA107959cRev2025 logging' do
    context 'when statement_of_truth_signature is missing' do
      let(:data_without_signature) do
        {
          'primary_contact_info' => { 'name' => { 'first' => 'Test', 'last' => 'User' } },
          'form_number' => '10-7959C'
        }
      end
      let(:form_without_signature) { IvcChampva::VHA107959cRev2025.new(data_without_signature) }

      it 'logs missing signature data' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA107959cRev2025 Missing stamp data for statement_of_truth_signature/)
            .and(matching(/form_number: 10-7959C/))
        )

        form_without_signature.desired_stamps
      end
    end

    context 'when statement_of_truth_signature is blank' do
      let(:data_with_blank_signature) do
        {
          'primary_contact_info' => { 'name' => { 'first' => 'Test', 'last' => 'User' } },
          'statement_of_truth_signature' => '',
          'form_number' => '10-7959C'
        }
      end
      let(:form_with_blank_signature) { IvcChampva::VHA107959cRev2025.new(data_with_blank_signature) }

      it 'logs missing signature data for blank value' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA107959cRev2025 Missing stamp data for statement_of_truth_signature/)
            .and(matching(/form_number: 10-7959C/))
        )

        form_with_blank_signature.desired_stamps
      end
    end
  end

  describe 'Feature flag control' do
    let(:fixture_path) { Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json') }
    let(:fixture_data) { JSON.parse(fixture_path.read) }

    context 'when logging is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_stamper_logging).and_return(false)
      end

      let(:data_without_veteran_country) do
        fixture_data.merge('veteran' => fixture_data['veteran'].merge('address' => {}))
      end
      let(:form_without_veteran_country) { IvcChampva::VHA1010d.new(data_without_veteran_country) }

      it 'does not log when feature flag is disabled' do
        expect(Rails.logger).not_to receive(:info)

        form_without_veteran_country.desired_stamps
      end
    end
  end

  describe 'Concern methods' do
    let(:form_instance) { IvcChampva::VHA1010d.new({ 'form_number' => '10-10D' }) }

    describe '#log_missing_field' do
      it 'logs missing field with context' do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/IVC ChampVA Forms - VHA1010d Missing stamp data for test_field/)
            .and(matching(/form_number: 10-10D/))
            .and(matching(/test_context: test_value/))
        )

        form_instance.send(:log_missing_field, 'test_field', { test_context: 'test_value' })
      end
    end

    describe '#log_missing_stamp_data' do
      it 'logs multiple missing fields' do
        expect(Rails.logger).to receive(:info).twice

        form_instance.send(:log_missing_stamp_data, {
                             'field1' => { value: nil },
                             'field2' => { value: '' },
                             'field3' => { value: 'present' }
                           })
      end
    end
  end
end
