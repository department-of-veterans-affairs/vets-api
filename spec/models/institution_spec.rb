# frozen_string_literal: true
RSpec.describe Institution, type: :model do
  subject { build :institution }

  describe 'Subject is valid' do
    specify { expect(subject).to be_valid }
  end

  describe 'institution types' do
    it 'cannot be blank' do
      expect(build(:institution, institution_type_id: nil)).not_to be_valid
    end
  end

  describe 'facility codes' do
    it 'are unique' do
      subject.save!

      duplicate_fc = build(:institution, facility_code: subject.facility_code)
      expect(duplicate_fc).not_to be_valid
    end

    it 'cannot be blank' do
      expect(build(:institution, facility_code: nil)).not_to be_valid
    end
  end

  describe 'institution names' do
    it 'cannot be blank' do
      expect(build(:institution, institution: nil)).not_to be_valid
    end
  end

  describe 'countries' do
    it 'cannot be blank' do
      expect(build(:institution, country: nil)).not_to be_valid
    end
  end

  describe 'when evaluating a tristate boolean' do
    let(:credit_for_mil_training) { build(:institution, credit_for_mil_training: nil) }
    let(:vet_poc) { build(:institution, vet_poc: nil) }
    let(:student_vet_grp_ipeds) { build(:institution, student_vet_grp_ipeds: nil) }
    let(:soc_member) { build(:institution, soc_member: nil) }
    let(:online_all) { build(:institution, online_all: nil) }
    let(:caution_flag) { build(:institution, caution_flag: nil) }

    it 'nil is not false' do
      expect(credit_for_mil_training.credit_for_mil_training == false).to be_falsey
      expect(vet_poc.vet_poc == false).to be_falsey
      expect(student_vet_grp_ipeds.student_vet_grp_ipeds == false).to be_falsey
      expect(soc_member.soc_member == false).to be_falsey
      expect(online_all.online_all == false).to be_falsey
      expect(caution_flag.caution_flag == false).to be_falsey
    end
  end

  describe 'when getting an institution type' do
    let(:flight) { create :institution_type, name: 'flight' }
    let(:correspondence) { create :institution_type, name: 'correspondence' }
    let(:ojt) { create :institution_type, name: 'ojt' }
    let(:pub) { create :institution_type, name: 'public' }
    let(:pri) { create :institution_type, name: 'private' }
    let(:profit) { create :institution_type, name: 'for profit' }
    let(:foreign) { create :institution_type, name: 'foreign' }
    let(:inst) { build :institution }

    it 'flight institutions are schools' do
      inst.institution_type = flight

      exp = [inst.flight?, inst.correspondence?, inst.ojt?, inst.school?]
      val = [true, false, false, true]
      expect(exp).to eq(val)
    end

    it 'correspondence institutions are schools' do
      inst.institution_type = correspondence

      exp = [inst.flight?, inst.correspondence?, inst.ojt?, inst.school?]
      val = [false, true, false, true]
      expect(exp).to eq(val)
    end

    it 'ojt institutions are not schools' do
      inst.institution_type = ojt
      exp = [inst.flight?, inst.correspondence?, inst.ojt?, inst.school?]
      val = [false, false, true, false]

      expect(exp).to eq(val)
    end

    it 'other institutions are schools' do
      exp = [inst.flight?, inst.correspondence?, inst.ojt?, inst.school?]
      val = [false, false, false, true]

      [pub, pri, profit, foreign].each do |school|
        inst.institution_type = school
        expect(exp).to eq(val)
      end
    end
  end

  describe 'when autocompleting' do
    let!(:nyc) { create_list :institution, 10, :in_nyc }
    let!(:chicago) { create_list :institution, 10, :in_chicago }
    let!(:start_like_harvard) { create_list :institution, 10, :start_like_harv }
    let!(:contains_harv) { create_list :institution, 10, :contains_harv }
    let!(:mit) { create :institution, institution: 'massachussets institute of technology' }

    it 'gets a single institution with unique name' do
      inst = Institution.autocomplete('massachussets institute of technology')

      expect(inst.size).to eql(1)
      expect(inst.first.value).to eq(mit.facility_code)
      expect(inst.first.label).to eq(mit.institution)
    end

    it 'gets institutions beginning with partial name' do
      inst = Institution.autocomplete('harv')

      expect(inst.size).to eql(start_like_harvard.size)
      inst.each do |i|
        expect(i.label.start_with?('harv')).to be_present
        expect(i.label =~ /.+harv/).to be_nil
      end
    end

    it 'can handle leading and trailing blanks' do
      inst = Institution.autocomplete('    harv     ')

      expect(inst.size).to eql(start_like_harvard.size)
      inst.each do |i|
        expect(i.label.start_with?('harv')).to be_present
        expect(i.label =~ /.+harv/).to be_nil
      end
    end

    it 'nil or empty returns all institutions' do
      [nil, '', '      '].each do |arg|
        inst = Institution.autocomplete(arg)
        expect(inst.size).to eql(Institution.all.count)
      end
    end
  end

  describe 'when searching' do
    let!(:nyc) { create_list :institution, 10, :in_nyc }
    let!(:new_rochelle) { create_list :institution, 10, :in_new_rochelle }
    let!(:chicago) { create_list :institution, 10, :in_chicago }
    let!(:u_chi_not_in_chi) { create :institution, :uchicago }
    let!(:start_like_harvard) { create_list :institution, 10, :start_like_harv }
    let!(:contains_harv) { create_list :institution, 10, :contains_harv }
    let!(:mit) { create :institution, institution: 'massachussets institute of technology' }

    it 'facility codes produce an exact match' do
      inst = Institution.search(mit.facility_code)

      expect(inst.size).to eql(1)
      expect(inst.first.facility_code).to eq(mit.facility_code)
    end

    it 'gets institutions by partial name' do
      inst = Institution.search('harv')

      expect(inst.size).to eql(start_like_harvard.size + contains_harv.size)
      inst.each do |i|
        expect(i.institution =~ /\Aharv|.+harv/).to be_present
      end
    end

    it 'gets institutions by city' do
      inst = Institution.search('new york')
      expect(inst.pluck(:city).uniq).to contain_exactly('new york')

      inst = Institution.search('new')
      expect(inst.pluck(:city).uniq).to contain_exactly('new york', 'new rochelle')
    end

    it 'gets institutions by city or name' do
      inst = Institution.search('chicago')

      expect(inst.size).to eq(chicago.size + 1)
      expect(inst.pluck(:institution)).to include('university of chicago - not in chicago')
      expect(inst.pluck(:city).uniq).to contain_exactly('chicago', 'some other city')
    end

    it 'queries are case insensitive' do
      inst1 = Institution.search('NEW YORK')
      inst2 = Institution.search('new york')

      expect(inst1).to eq(inst2)
    end
  end
end
