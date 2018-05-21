# frozen_string_literal: true

require 'rails_helper'
require 'support/attr_encrypted_matcher'

RSpec.describe FormProfile, type: :model do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }

  before do
    user.va_profile.suffix = 'Jr.'
    user.va_profile.address.country = 'USA'
    stub_evss_pciu(user)
  end

  let(:form_profile) do
    described_class.new('foo')
  end

  let(:us_phone) do
    form_profile.send(
      :get_us_phone,
      user.pciu_primary_phone
    )
  end

  let(:veteran_full_name) do
    {
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      }
    }
  end

  let(:veteran_address) do
    {
      'veteranAddress' => {
        'street' => user.va_profile[:address][:street],
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      }
    }
  end

  let(:v21_686_c_expected) do
    {
      'claimantAddress' => veteran_address['veteranAddress'],
      'claimantFullName' => veteran_full_name['veteranFullName'],
      'dayPhone' => us_phone,
      'claimantSocialSecurityNumber' => user.ssn,
      'claimantEmail' => user.pciu_email
    }
  end

  let(:v22_1990_expected) do
    {
      'toursOfDuty' => [
        {
          'service_branch' => 'Air Force',
          'date_range' => {
            'from' => '2007-04-01', 'to' => '2016-06-01'
          }
        }
      ],
      'currentlyActiveDuty' => {
        'yes' => true
      },
      'veteranAddress' => {
        'street' => user.va_profile[:address][:street],
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      },
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'gender' => user.gender,
      'homePhone' => us_phone,
      'veteranDateOfBirth' => user.birth_date,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.pciu_email
    }
  end

  let(:v22_1990_n_expected) do
    {
      'toursOfDuty' => [
        {
          'service_branch' => 'Air Force',
          'date_range' => {
            'from' => '2007-04-01', 'to' => '2016-06-01'
          }
        }
      ],
      'currentlyActiveDuty' => {
        'yes' => true
      },
      'veteranAddress' => {
        'street' => user.va_profile[:address][:street],
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      },
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'gender' => user.gender,
      'homePhone' => us_phone,
      'veteranDateOfBirth' => user.birth_date,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.pciu_email
    }
  end

  let(:v22_1990_e_expected) do
    {
      'relativeAddress' => {
        'street' => user.va_profile[:address][:street],
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      },
      'relativeFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'relativeSocialSecurityNumber' => user.ssn
    }
  end

  let(:v22_1995_expected) do
    {
      'veteranAddress' => {
        'street' => user.va_profile[:address][:street],
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      },
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'homePhone' => us_phone,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.pciu_email
    }
  end

  let(:v22_5490_expected) do
    {
      'toursOfDuty' => [
        {
          'service_branch' => 'Air Force',
          'date_range' => {
            'from' => '2007-04-01', 'to' => '2016-06-01'
          }
        }
      ],
      'currentlyActiveDuty' => true,
      'relativeFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'relativeSocialSecurityNumber' => user.ssn,
      'relativeDateOfBirth' => user.birth_date
    }
  end

  let(:v22_5495_expected) do
    {
      'toursOfDuty' => [
        {
          'service_branch' => 'Air Force',
          'date_range' => {
            'from' => '2007-04-01', 'to' => '2016-06-01'
          }
        }
      ],
      'currentlyActiveDuty' => true,
      'relativeFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'relativeSocialSecurityNumber' => user.ssn,
      'relativeDateOfBirth' => user.birth_date
    }
  end

  let(:v1010ez_expected) do
    {
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'veteranDateOfBirth' => user.birth_date,
      'email' => user.pciu_email,
      'veteranAddress' => {
        'street' => user.va_profile[:address][:street],
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      },
      'swAsiaCombat' => true,
      'lastServiceBranch' => 'air force',
      'lastEntryDate' => '2007-04-01',
      'lastDischargeDate' => '2007-04-02',
      'dischargeType' => 'honorable',
      'postNov111998Combat' => true,
      'gender' => user.gender,
      'homePhone' => us_phone,
      'veteranSocialSecurityNumber' => user.ssn,
      'vaCompensationType' => 'highDisability'
    }
  end

  let(:vvic_expected) do
    {
      'email' => user.pciu_email,
      'serviceBranches' => ['F'],
      'gender' => user.gender,
      'verified' => true,
      'veteranDateOfBirth' => user.birth_date,
      'phone' => us_phone,
      'veteranSocialSecurityNumber' => user.ssn
    }.merge(veteran_full_name).merge(veteran_address)
  end

  let(:v21_p_527_ez_expected) do
    {
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'veteranAddress' => {
        'street' => user.va_profile[:address][:street],
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      },
      'gender' => user.gender,
      'dayPhone' => us_phone,
      'veteranSocialSecurityNumber' => user.ssn,
      'veteranDateOfBirth' => user.birth_date
    }
  end

  let(:v21_p_530_expected) do
    {
      'claimantFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'claimantAddress' => {
        'street' => user.va_profile[:address][:street],
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      },
      'claimantPhone' => us_phone,
      'claimantEmail' => user.pciu_email
    }
  end

  before(:each) do
    described_class.instance_variable_set(:@mappings, nil)
  end

  describe '#get_us_phone' do
    def self.test_get_us_phone(phone, expected)
      it "should return #{expected}" do
        expect(form_profile.send(:get_us_phone, phone)).to eq(expected)
      end
    end

    context 'with nil' do
      test_get_us_phone(nil, '')
    end

    context 'with an intl phone number' do
      test_get_us_phone('442079460976', '')
    end

    context 'with a us phone number' do
      test_get_us_phone('5557940976', '5557940976')
    end

    context 'with a us phone number' do
      test_get_us_phone('15557940976', '5557940976')
    end
  end

  describe '#prefill_form' do
    def can_prefill_emis(yes)
      expect(user).to receive(:authorize).with(:emis, :access?).and_return(yes)
    end

    def expect_prefilled(form_id)
      prefilled_data = Oj.load(described_class.for(form_id).prefill(user).to_json)['form_data']

      if form_id == '1010ez'
        '10-10EZ'
      else
        form_id
      end.tap do |schema_form_id|
        schema = VetsJsonSchema::SCHEMAS[schema_form_id].except('required', 'anyOf')
        schema_data = prefilled_data.deep_dup

        schema_data.except!('verified', 'serviceBranches') if schema_form_id == 'VIC'

        errors = JSON::Validator.fully_validate(
          schema,
          schema_data.deep_transform_keys { |key| key.camelize(:lower) },
          validate_schema: true
        )
        expect(errors.empty?).to eq(true), "schema errors: #{errors}"
      end
      expect(prefilled_data).to eq(
        form_profile.send(:clean!, public_send("v#{form_id.underscore}_expected"))
      )
    end

    context 'when emis is down', skip_emis: true do
      it 'should log the error to sentry' do
        can_prefill_emis(true)
        error = RuntimeError.new('foo')
        expect(Rails.env).to receive(:production?).and_return(true)
        expect(user.military_information).to receive(:last_service_branch).and_return('air force').and_raise(error)

        form_profile = described_class.for('1010ez')
        expect(form_profile).to receive(:log_exception_to_sentry).with(error, {}, backend_service: :emis)
        form_profile.prefill(user)
      end
    end

    context 'with emis data', skip_emis: true do
      before do
        military_information = user.military_information
        expect(military_information).to receive(:last_service_branch).and_return('air force')
        expect(military_information).to receive(:last_entry_date).and_return('2007-04-01')
        expect(military_information).to receive(:last_discharge_date).and_return('2007-04-02')
        expect(military_information).to receive(:discharge_type).and_return('honorable')
        expect(military_information).to receive(:post_nov111998_combat).and_return(true)
        expect(military_information).to receive(:sw_asia_combat).and_return(true)
        expect(military_information).to receive(:compensable_va_service_connected).and_return(true).twice
        expect(military_information).to receive(:is_va_service_connected).and_return(true).twice
        expect(military_information).to receive(:tours_of_duty).and_return(
          [{ service_branch: 'Air Force', date_range: { from: '2007-04-01', to: '2016-06-01' } }]
        )
        expect(military_information).to receive(:service_branches).and_return(['F'])
        allow(military_information).to receive(:currently_active_duty_hash).and_return(
          yes: true
        )
        expect(user).to receive(:can_access_id_card?).and_return(true)
      end

      context 'with a user that can prefill emis' do
        before do
          can_prefill_emis(true)
        end

        it 'returns prefilled VIC' do
          expect_prefilled('VIC')
        end

        it 'returns prefilled 22-1990' do
          expect_prefilled('22-1990')
        end

        it 'returns prefilled 22-1990N' do
          expect_prefilled('22-1990N')
        end

        it 'returns prefilled 22-1990E' do
          expect_prefilled('22-1990E')
        end

        it 'returns prefilled 22-1995' do
          expect_prefilled('22-1995')
        end

        it 'returns prefilled 22-5490' do
          expect_prefilled('22-5490')
        end

        it 'returns prefilled 22-5495' do
          expect_prefilled('22-5495')
        end

        it 'returns prefilled 21-686C' do
          expect_prefilled('21-686C')
        end

        it 'returns the va profile mapped to the healthcare form' do
          expect_prefilled('1010ez')
        end
      end
    end

    context 'with a burial application form' do
      it 'returns the va profile mapped to the burial form' do
        expect_prefilled('21P-530')
      end
    end

    context 'with a pension application form' do
      it 'returns the va profile mapped to the pension form' do
        expect_prefilled('21P-527EZ')
      end
    end

    context 'when the form mapping can not be found' do
      it 'raises an IOError' do
        expect { described_class.new('foo').prefill(user) }.to raise_error(IOError)
      end
    end
  end

  describe '.mappings_for_form' do
    context 'with multiple form profile instances' do
      let(:instance1) { FormProfile.new('1010ez') }
      let(:instance2) { FormProfile.new('1010ez') }

      it 'loads the yaml file only once' do
        expect(YAML).to receive(:load_file).once.and_return(
          'veteran_full_name' => %w[identity_information full_name],
          'gender' => %w[identity_information gender],
          'veteran_date_of_birth' => %w[identity_information date_of_birth],
          'veteran_address' => %w[contact_information address],
          'home_phone' => %w[contact_information home_phone]
        )
        instance1.prefill(user)
        instance2.prefill(user)
      end
    end
  end
end
