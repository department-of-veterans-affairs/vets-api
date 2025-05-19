require 'rails_helper'

RSpec.describe FormEligibility::FormConnectorService do
  let(:mock_routing_config_path) { Rails.root.join('config', 'forms_eligibility', 'routing.yml') }
  let(:mock_1010d_rules_path) { Rails.root.join('config', 'forms_eligibility', 'rules', '10-10D.yml') }

  let(:valid_1010d_rules) do
    {
      'description' => 'Test 10-10D Rules',
      'rules' => [
        {
          'name' => 'Spouse of Living P&T Vet',
          'if' => {
            'relationship_to_veteran' => 'spouse',
            'sc_disability_is_permanent_and_total' => true
          },
          'then' => {
            'eligible' => true, 'reason' => 'Spouse of living P&T Vet eligible.',
            'confidence' => 'medium', 'target_form_name' => '10-10D'
            # No clarifying_questions for this one as it relies on interpreted 10-10EZ data
          }
        },
        {
          'name' => 'Child of Living P&T Vet - Eligible Age/Status',
          'if' => {
            'relationship_to_veteran' => 'child',
            'sc_disability_is_permanent_and_total' => true,
            'child_is_eligible_age_or_status' => true
          },
          'then' => {
            'eligible' => true, 'reason' => 'Child of living P&T Vet eligible (age/status).',
            'confidence' => 'medium', 'target_form_name' => '10-10D'
          }
        },
        {
          'name' => 'Surviving Spouse P&T at Death',
          'if' => {
            'relationship_to_veteran' => 'spouse',
            'veteran_deceased' => true,
            'sc_disability_was_permanent_and_total_at_death' => true
          },
          'then' => {
            'eligible' => true, 'reason' => 'Surviving spouse of P&T Vet at death.',
            'confidence' => 'low', 'target_form_name' => '10-10D',
            'clarifying_questions' => ["Is the Veteran deceased?", "Was P&T at death?"] # Mock questions
          }
        }
      ]
    }
  end

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
              'sc_disability_was_permanent_and_total_at_death' => 'veteranInfo.scPAndTAtDeath'
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
        allow(YAML).to receive(:load_file).with(mock_routing_config_path).and_raise(Psych::SyntaxError.new('dummy_file.yml', 1, 1, 0, 'problem', 'context'))
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
    before do
      # More aggressive default mocking for file operations for this describe block:
      # Default all File.exist? to false unless specifically allowed for a path.
      allow(File).to receive(:exist?).and_return(false)
      # Default all YAML.load_file to raise an error unless specifically allowed.
      allow(YAML).to receive(:load_file).and_raise("Unexpected YAML.load_file call in test with path arguments!")

      # Specifically allow the expected file operations for a successful service initialization and rule loading path:
      allow(File).to receive(:exist?).with(mock_routing_config_path).and_return(true)
      allow(YAML).to receive(:load_file).with(mock_routing_config_path).and_return(routing_config_1010ez_to_1010d)
      
      allow(File).to receive(:exist?).with(mock_1010d_rules_path).and_return(true)
      allow(YAML).to receive(:load_file).with(mock_1010d_rules_path).and_return(valid_1010d_rules)
    end

    subject(:service) { described_class.new }
    let(:completed_form_id) { '10-10EZ' }

    context 'for spouse of living P&T Veteran' do
      let(:submitted_data) do
        {
          '_meta' => { 'relationship_to_veteran' => 'spouse' },
          'veteranInfo' => { 'vaCompensationType' => 'highDisability' }
        }
      end

      it 'suggests 10-10D without clarifying questions' do
        suggestions = service.suggest_forms(completed_form_id, submitted_data)
        expect(suggestions.size).to eq(1)
        suggestion = suggestions.first
        expect(suggestion['target_form_id']).to eq('10-10D')
        expect(suggestion['rule_name']).to eq('Spouse of Living P&T Vet')
        expect(suggestion['clarifying_questions']).to be_nil
      end
    end

    context 'for child of living P&T Veteran (Eligible Age/Status)' do
      let(:submitted_data) do
        {
          '_meta' => { 'relationship_to_veteran' => 'child' },
          'applicantDetails' => { 'dateOfBirth' => (Date.today - 17.years).to_s },
          'veteranInfo' => { 'vaCompensationType' => 'highDisability' }
        }
      end

      it 'suggests 10-10D without clarifying questions' do
        suggestions = service.suggest_forms(completed_form_id, submitted_data)
        expect(suggestions.size).to eq(1)
        suggestion = suggestions.first
        expect(suggestion['target_form_id']).to eq('10-10D')
        expect(suggestion['rule_name']).to eq('Child of Living P&T Vet - Eligible Age/Status')
        expect(suggestion['clarifying_questions']).to be_nil
      end
    end
    
    context 'for child of living P&T Veteran (student under 23)' do
      let(:submitted_data) do
        {
          '_meta' => { 'relationship_to_veteran' => 'child' },
          'applicantDetails' => { 
            'dateOfBirth' => (Date.today - 20.years).to_s, # 20 years old
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
        expect(suggestion['rule_name']).to eq('Child of Living P&T Vet - Eligible Age/Status')
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

      it 'does not suggest 10-10D based on child P&T rule' do
        suggestions = service.suggest_forms(completed_form_id, submitted_data)
        expect(suggestions.any? { |s| s['rule_name'] == 'Child of Living P&T Vet - Eligible Age/Status' }).to be_falsey
      end
    end

    context 'when Veteran is not P&T (low disability)' do
      let(:submitted_data) do
        {
          '_meta' => { 'relationship_to_veteran' => 'spouse' },
          'veteranInfo' => { 'vaCompensationType' => 'lowDisability' }
        }
      end

      it 'does not suggest 10-10D based on P&T rules' do
        suggestions = service.suggest_forms(completed_form_id, submitted_data)
        expect(suggestions.any? { |s| s['rule_name'] == 'Spouse of Living P&T Vet' }).to be_falsey
      end
    end

    context 'for surviving spouse of P&T Vet at death (data provided)' do
      let(:submitted_data) do
        {
          '_meta' => { 'relationship_to_veteran' => 'spouse' },
          'veteranInfo' => { 
            'isDeceased' => true,
            'scPAndTAtDeath' => true
          }
        }
      end

      it 'suggests 10-10D with clarifying questions' do
        suggestions = service.suggest_forms(completed_form_id, submitted_data)
        expect(suggestions.size).to eq(1)
        suggestion = suggestions.first
        expect(suggestion['target_form_id']).to eq('10-10D')
        expect(suggestion['rule_name']).to eq('Surviving Spouse P&T at Death')
        expect(suggestion['clarifying_questions']).to eq(["Is the Veteran deceased?", "Was P&T at death?"])
      end
    end

    context 'when target form rule file does not exist (File.exist? is false)' do
      before do
        allow(File).to receive(:exist?).with(mock_1010d_rules_path).and_return(false)
      end

      it 'returns no suggestions and does not log specific file load errors for that path' do
        suggestions = service.suggest_forms(completed_form_id, { 'some' => 'data' })
        expect(suggestions).to be_empty
        expect(Rails.logger).not_to have_received(:error).with("Rules file not found: #{mock_1010d_rules_path}")
        expect(Rails.logger).not_to have_received(:error).with(/Error parsing YAML in rules file #{Regexp.escape(mock_1010d_rules_path.to_s)}/)
      end
    end

    context 'when rule file exists but YAML.load_file raises Errno::ENOENT' do
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