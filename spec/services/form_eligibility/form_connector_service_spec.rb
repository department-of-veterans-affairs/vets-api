require 'rails_helper'

RSpec.describe FormEligibility::FormConnectorService do
  let(:mock_routing_config_path) { Rails.root.join('config', 'forms_eligibility', 'routing.yml') }
  let(:mock_1010d_rules_path) { Rails.root.join('config', 'forms_eligibility', 'rules', '10-10D.yml') }

  let(:routing_config_1010ez_to_1010d) do
    {
      '10-10EZ' => {
        'suggested_forms' => [
          {
            'target_form_id' => '10-10D',
            'rules_file' => 'rules/10-10D.yml',
            'data_mapping' => {
              'relationship_to_veteran' => '_meta.relationship_to_veteran',
              'sc_disability_is_permanent_and_total' => 'veteranInfo.vaCompensationType',
              'child_date_of_birth' => 'applicantDetails.dateOfBirth',
              'child_attended_school_last_year' => 'applicantDetails.attendedSchoolLastYear',
              'veteran_deceased' => 'veteranInfo.isDeceased',
              'sc_disability_was_permanent_and_total_at_death' => 'veteranInfo.scPAndTAtDeath',
              'died_in_line_of_duty' => 'veteranInfo.disabledInLineOfDuty',
              'died_from_sc_disability' => 'veteranInfo.diedFromSCDisability'
            }
          }
        ]
      }
    }
  end

  # General before block for logger
  before do
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
  end

  describe '#initialize' do
    context 'when routing file is missing' do
      before do
        allow(File).to receive(:exist?).with(mock_routing_config_path).and_return(false)
        allow(YAML).to receive(:load_file).with(mock_routing_config_path).and_raise(Errno::ENOENT.new(mock_routing_config_path.to_s))
      end

      it 'logs an error and initializes with empty rules' do
        expect(Rails.logger).to receive(:error).with("Form routing rules file not found at #{mock_routing_config_path}")
        service_instance = described_class.new
        expect(service_instance.instance_variable_get(:@routing_rules)).to eq({})
      end
    end

    context 'when routing file has syntax errors' do
      before do
        allow(File).to receive(:exist?).with(mock_routing_config_path).and_return(true)
        allow(YAML).to receive(:load_file).with(mock_routing_config_path).and_raise(Psych::SyntaxError.new(
                                                                                      'dummy_file.yml', 1, 1, 0, 'problem', 'context'
                                                                                    ))
      end

      it 'logs an error and initializes with empty rules' do
        expect(Rails.logger).to receive(:error).with(/Error parsing YAML in form routing rules at #{Regexp.escape(mock_routing_config_path.to_s)}: .*problem/)
        service_instance = described_class.new
        expect(service_instance.instance_variable_get(:@routing_rules)).to eq({})
      end
    end

    context 'when routing file loads correctly' do
      before do
        allow(File).to receive(:exist?).with(mock_routing_config_path).and_return(true)
        allow(YAML).to receive(:load_file).with(mock_routing_config_path).and_return(routing_config_1010ez_to_1010d)
      end

      it 'loads the routing rules' do
        service_instance = described_class.new
        expect(service_instance.instance_variable_get(:@routing_rules)).to eq(routing_config_1010ez_to_1010d)
      end
    end
  end

  describe '#suggest_forms' do
    subject(:service) { described_class.new }

    before do
      # More aggressive default mocking for file operations for this describe block:
      # Default all File.exist? to false unless specifically allowed for a path.
      allow(File).to receive(:exist?).and_return(false)
      # Default all YAML.load_file to raise an error unless specifically allowed.
      allow(YAML).to receive(:load_file).and_raise('Unexpected YAML.load_file call in test with path arguments!')

      # Specifically allow the expected file operations for a successful service initialization and rule loading path:
      allow(File).to receive(:exist?).with(mock_routing_config_path).and_return(true)
      allow(YAML).to receive(:load_file).with(mock_routing_config_path).and_return(routing_config_1010ez_to_1010d)

      allow(File).to receive(:exist?).with(mock_1010d_rules_path).and_return(true)
      allow(YAML).to receive(:load_file).with(mock_1010d_rules_path).and_call_original
    end

    let(:completed_form_id) { '10-10EZ' }

    context 'for spouse of living P&T Veteran' do
      let(:submitted_data) do
        {
          '_meta' => { 'relationship_to_veteran' => 'spouse' },
          'veteranInfo' => { 'vaCompensationType' => 'highDisability' }
        }
      end

      it 'suggests 10-10D with correct details from actual rule file' do
        suggestions = service.suggest_forms(completed_form_id, submitted_data)
        expect(suggestions.size).to eq(1)
        suggestion = suggestions.first
        expect(suggestion['target_form_id']).to eq('10-10D')
        expect(suggestion['rule_name']).to eq('Spouse of living Veteran rated P&T for SC disability')
        expect(suggestion['eligible']).to be true
        expect(suggestion['reason']).to eq('You may be eligible as the spouse of a Veteran rated permanently and totally disabled from a service-connected disability.')
        expect(suggestion['confidence']).to eq('medium')
        expect(suggestion['target_form_name']).to eq('10-10D')
        expect(suggestion['target_form_description']).to eq('Application for CHAMPVA Benefits')
        expect(suggestion['notes']).to eq('Assumes Veteran is alive. TRICARE eligibility not checked.')
        expect(suggestion['clarifying_questions']).to be_nil
      end
    end

    context 'for child of living P&T Veteran (Eligible Age/Status - e.g., 17 years old)' do
      let(:submitted_data) do
        {
          '_meta' => { 'relationship_to_veteran' => 'child' },
          'applicantDetails' => { 'dateOfBirth' => (Date.today - 17.years).to_s },
          'veteranInfo' => { 'vaCompensationType' => 'highDisability' }
        }
      end

      it 'suggests 10-10D with correct details from actual rule file' do
        suggestions = service.suggest_forms(completed_form_id, submitted_data)
        expect(suggestions.size).to eq(1)
        suggestion = suggestions.first
        expect(suggestion['target_form_id']).to eq('10-10D')
        expect(suggestion['rule_name']).to eq('Child of living Veteran rated P&T for SC disability')
        expect(suggestion['eligible']).to be true
        expect(suggestion['reason']).to eq('You may be eligible as the child of a Veteran rated permanently and totally disabled from a service-connected disability.')
        expect(suggestion['confidence']).to eq('medium')
        expect(suggestion['notes']).to eq('Assumes Veteran is alive. TRICARE eligibility not checked.')
        expect(suggestion['clarifying_questions']).to be_nil
      end
    end

    context 'for child of living P&T Veteran (student under 23 - e.g., 20 years old, student)' do
      let(:submitted_data) do
        {
          '_meta' => { 'relationship_to_veteran' => 'child' },
          'applicantDetails' => { 
            'dateOfBirth' => (Date.today - 20.years).to_s,
            'attendedSchoolLastYear' => true 
          },
          'veteranInfo' => { 'vaCompensationType' => 'highDisability' }
        }
      end

      it 'suggests 10-10D' do
        suggestions = service.suggest_forms(completed_form_id, submitted_data)
        expect(suggestions.size).to eq(1)
        suggestion = suggestions.first
        expect(suggestion['target_form_id']).to eq('10-10D')
        expect(suggestion['rule_name']).to eq('Child of living Veteran rated P&T for SC disability')
      end
    end

    context 'for child of living P&T Veteran (ineligible - over 18, not student)' do
      let(:submitted_data) do
        {
          '_meta' => { 'relationship_to_veteran' => 'child' },
          'applicantDetails' => { 
            'dateOfBirth' => (Date.today - 20.years).to_s, 
            'attendedSchoolLastYear' => false 
          },
          'veteranInfo' => { 'vaCompensationType' => 'highDisability' }
        }
      end

      it 'does not suggest 10-10D based on this child P&T rule' do
        suggestions = service.suggest_forms(completed_form_id, submitted_data)
        expect(suggestions.any? { |s| s['rule_name'] == 'Child of living Veteran rated P&T for SC disability' }).to be_falsey
      end
    end

    context 'when Veteran is not P&T (low disability)' do
      let(:submitted_data) do
        {
          '_meta' => { 'relationship_to_veteran' => 'spouse' },
          'veteranInfo' => { 'vaCompensationType' => 'lowDisability' }
        }
      end

      it 'does not suggest 10-10D based on P&T rules for spouse' do
        suggestions = service.suggest_forms(completed_form_id, submitted_data)
        expect(suggestions.any? { |s| s['rule_name'] == 'Spouse of living Veteran rated P&T for SC disability' }).to be_falsey
      end
    end

    context 'for surviving spouse of Veteran P&T at death (data provided)' do
      let(:submitted_data) do
        {
          '_meta' => { 'relationship_to_veteran' => 'spouse' },
          'veteranInfo' => { 
            'isDeceased' => true,
            'scPAndTAtDeath' => true
          }
        }
      end

      it 'suggests 10-10D with correct details and clarifying questions from actual rule file' do
        suggestions = service.suggest_forms(completed_form_id, submitted_data)
        expect(suggestions.size).to eq(1)
        suggestion = suggestions.find { |s| s['rule_name'] == 'Surviving spouse of Veteran who was P&T for SC disability at time of death' }
        expect(suggestion).not_to be_nil
        
        expect(suggestion['target_form_id']).to eq('10-10D')
        expect(suggestion['eligible']).to be true
        expect(suggestion['reason']).to eq('You may be eligible as the surviving spouse of a Veteran who was rated permanently and totally disabled from a service-connected disability at the time of death.')
        expect(suggestion['confidence']).to eq('low')
        expect(suggestion['notes']).to eq('TRICARE eligibility not checked.')
        expect(suggestion['clarifying_questions']).to eq([
          "Is the Veteran deceased?",
          "At the time of death, was the Veteran rated permanently and totally disabled due to a service-connected condition?"
        ])
      end
    end

    context 'when target form rule file does not exist (File.exist? is false for rule file)' do
      before do
        allow(File).to receive(:exist?).with(mock_1010d_rules_path).and_return(false)
        allow(YAML).to receive(:load_file).with(mock_1010d_rules_path).and_raise("Should not be called if file doesn't exist")
      end

      it 'returns no suggestions and does not log specific file load errors for that path' do
        suggestions = service.suggest_forms(completed_form_id, { 'some' => 'data' })
        expect(suggestions).to be_empty
        expect(Rails.logger).not_to have_received(:error).with("Rules file not found: #{mock_1010d_rules_path}")
        expect(Rails.logger).not_to have_received(:error).with(/Error parsing YAML in rules file #{Regexp.escape(mock_1010d_rules_path.to_s)}/)
      end
    end

    context 'when rule file exists but YAML.load_file raises Errno::ENOENT (e.g., race condition or bad path internally)' do
      before do
        allow(File).to receive(:exist?).with(mock_1010d_rules_path).and_return(true)
        allow(YAML).to receive(:load_file).with(mock_1010d_rules_path).and_raise(Errno::ENOENT.new(mock_1010d_rules_path.to_s))
      end

      it 'logs a "Rules file not found" error and returns no suggestions' do
        expect(Rails.logger).to receive(:error).with("Rules file not found: #{mock_1010d_rules_path}")
        suggestions = service.suggest_forms(completed_form_id, { 'some' => 'data' })
        expect(suggestions).to be_empty
      end
    end

    context 'when completed_form_id is not in routing rules' do
      it 'returns an empty array' do
        suggestions = service.suggest_forms('UNKNOWN_FORM_ID', {})
        expect(suggestions).to be_empty
      end
    end
  end
end
