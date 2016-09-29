# frozen_string_literal: true
require 'rails_helper'

RSpec.describe User, type: :model do
  context 'on user instantiation' do
    let(:attributes) do
      {
        uuid: 'userid:123',
        email: 'test@test.com',
        first_name: 'John',
        middle_name: 'William',
        last_name: 'Smith',
        dob: Time.new(1980, 1, 1).utc,
        ssn: '555-44-3333',
        gender: 'M'
      }
    end

    subject { described_class.new(attributes) }

    before(:each) do
      allow(MVI::Service).to receive(:find_candidate).and_return(
        edipi: '1234^NI^200DOD^USDOD^A',
        icn: '1000123456V123456^NI^200M^USVHA^P',
        mhv: '123456^PI^200MHV^USVHA^A',
        status: 'active',
        given_names: %w(John William),
        family_name: 'Smith',
        gender: 'M',
        dob: '19800101',
        ssn: '555-44-3333'
      )
    end

    it 'expect ttl to an Integer' do
      expect(subject.ttl).to be_an(Integer)
      expect(subject.ttl).to eq(86400)
    end

    it 'has a persisted attribute of true' do
      expect(subject.persisted?).to be_truthy
    end

    it 'assigns an email' do
      expect(subject.email).to eq('test@test.com')
    end

    it 'assigns an uuid' do
      expect(subject.uuid).to eq('userid:123')
    end

    # TODO(AJD): aren't some of these actually testing RedisStore?
    describe 'redis persistence' do
      before(:each) { subject.save }

      describe '#save' do
        it 'sets persisted flag to true' do
          expect(subject.persisted?).to be_truthy
        end

        it 'sets the ttl countdown' do
          expect(subject.ttl).to be_an(Integer)
          expect(subject.ttl).to be_between(0, 86_400)
        end
      end

      describe '.find' do
        let(:found_user) { described_class.find(subject.uuid) }

        it 'can find a saved user in redis' do
          expect(found_user).to be_a(described_class)
          expect(found_user.uuid).to eq(subject.uuid)
        end

        it 'expires and returns nil if user loaded from redis is invalid' do
          allow_any_instance_of(described_class).to receive(:valid?).and_return(false)
          expect(found_user).to be_nil
        end

        it 'returns nil if user was not found' do
          expect(described_class.find('non-existant-uuid')).to be_nil
        end
      end

      describe '#update' do
        context 'with a partial update' do
          it 'updates only user the user attributes passed in as arguments' do
            expect(subject).to receive(:save).once
            subject.update(
              mvi: {
                edipi: '1234^NI^200DOD^USDOD^A',
                icn: '1000123456V123456^NI^200M^USVHA^P',
                mhv_id: '123456^PI^200MHV^USVHA^A'
              }
            )
            expect(subject.attributes).to eq(
              dob: Time.new(1980, 1, 1).utc,
              edipi: nil,
              email: attributes[:email],
              first_name: 'John',
              gender: 'M',
              last_name: 'Smith',
              last_signed_in: nil,
              middle_name: 'William',
              mvi: {
                edipi: '1234^NI^200DOD^USDOD^A',
                icn: '1000123456V123456^NI^200M^USVHA^P',
                mhv_id: '123456^PI^200MHV^USVHA^A'
              },
              participant_id: nil,
              ssn: '555-44-3333',
              uuid: attributes[:uuid],
              zip: nil
            )
          end
        end
      end

      describe '#destroy' do
        it 'can destroy a user in redis' do
          expect(subject.destroy).to eq(1)
          expect(described_class.find(subject.uuid)).to be_nil
        end
      end
    end

    describe '#fetch_mvi_data' do
      let(:uuid) { SecureRandom.uuid }
      let(:attributes) do
        {
          uuid: uuid,
          email: 'john.smith@foo.com',
          first_name: 'John',
          middle_name: 'William',
          last_name: 'Smith',
          gender: 'M',
          dob: Time.new(1980, 1, 1).utc,
          zip: '90210',
          ssn: '555-44-3333'
        }
      end

      context 'with a valid find candidate message' do
        it 'updates the mvi attributes' do
          user = described_class.new(attributes)
          expect(user.attributes).to eq(
            dob: Time.new(1980, 1, 1).utc,
            edipi: nil,
            email: 'john.smith@foo.com',
            first_name: 'John',
            gender: 'M',
            last_name: 'Smith',
            last_signed_in: nil,
            middle_name: 'William',
            mvi: {
              edipi: '1234^NI^200DOD^USDOD^A',
              icn: '1000123456V123456^NI^200M^USVHA^P',
              mhv: '123456^PI^200MHV^USVHA^A',
              status: 'active',
              given_names: %w(John William),
              family_name: 'Smith',
              gender: 'M',
              dob: '19800101',
              ssn: '555-44-3333'
            },
            participant_id: nil,
            ssn: '555-44-3333',
            uuid: uuid,
            zip: '90210'
          )
        end
      end
      context 'with an invalid find candidate message' do
        it 'should log a warn message' do
          expect { described_class.new(attributes.except(:ssn)) }.to raise_error(Common::Exceptions::ValidationErrors)
        end
      end
      context 'when a MVI::ServiceError is raised' do
        it 'should log an error message' do
          allow(MVI::Service).to receive(:find_candidate).and_raise(MVI::HTTPError)
          expect { described_class.new(attributes) }.to raise_error(Common::Exceptions::RecordNotFound)
        end
      end
    end
  end
end
