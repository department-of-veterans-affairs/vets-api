# frozen_string_literal: true
# frozen_string_literal: true
class VHAFacilityAdapter
  VHA_URL = +ENV['VHA_MAPSERVER_URL']
  VHA_LAYER = ENV['VHA_MAPSERVER_LAYER']
  VHA_ID_FIELD = 'StationNum'
  FACILITY_TYPE = 'va_health_facility'

  def initialize
    @client = Facilities::Client.new(url: VHA_URL, layer: VHA_LAYER, id_field: VHA_ID_FIELD)
  end

  def query(bbox, services = nil)
    @client.query(bbox: bbox.join(','),
                  where: VHAFacilityAdapter.where_clause(services))
  end

  def find_by(id:)
    @client.get(identifier: id)
  end

  def self.where_clause(services)
    services.map { |s| "#{s}='YES'" }.join(' AND ') unless services.nil?
  end

  def from_gis(record)
    attrs = record['attributes']
    m = from_gis_attrs(TOP_KEYMAP, attrs)
    m[:facility_type] = FACILITY_TYPE
    m[:address] = {}
    m[:address][:physical] = from_gis_attrs(ADDR_KEYMAP, attrs)
    m[:address][:physical][:zip] = attrs['Zip']
    m[:address][:physical][:zip] << '-' + attrs['Zip4'] unless attrs['Zip4'].strip.empty?
    m[:address][:mailing] = {}
    m[:phone] = from_gis_attrs(PHONE_KEYMAP, attrs)
    m[:hours] = from_gis_attrs(HOURS_KEYMAP, attrs)
    m[:services] = services_from_gis(attrs)
    VAFacility.new(m)
  end

  def service_whitelist
    SERVICE_HIERARCHY.flatten(2)
  end

  TOP_KEYMAP = {
    unique_id: 'StationNum',
    name: 'StationNam', classification: 'CocClassif',
    lat: 'Latitude', long: 'Longitude'
  }.freeze

  ADDR_KEYMAP = {
    'building' => 'Building', 'street' => 'Street', 'suite' => 'Suite',
    'city' => 'City', 'state' => 'State'
  }.freeze

  PHONE_KEYMAP = {
    'main' => 'MainPhone', 'fax' => 'MainFax', 'after_hours' => 'AfterHours',
    'patient_advocate' => 'PatientAdv',
    'enrollment_coordinator' => 'Enrollment',
    'pharmacy' => 'PharmacyPh'
  }.freeze

  HOURS_KEYMAP = %w(
    Monday Tuesday Wednesday Thursday Friday Saturday Sunday
  ).each_with_object({}) { |d, h| h[d] = d }

  SERVICE_HIERARCHY = {
    'Audiology' => [],
    'ComplementaryAlternativeMed' => [],
    'DentalServices' => [],
    'DiagnosticServices' => %w(
      ImagingAndRadiology LabServices
    ),
    'EmergencyDept' => [],
    'EyeCare' => [],
    'MentalHealthCare' => %w(
      OutpatientMHCare OutpatientSpecMHCare VocationalAssistance
    ),
    'OutpatientMedicalSpecialty' => %w(
      AllergyAndImmunology CardiologyCareServices DermatologyCareServices
      Diabetes Dialysis Endocrinology Gastroenterology
      Hematology InfectiousDisease InternalMedicine
      Nephrology Neurology Oncology
      PulmonaryRespiratoryDisease Rheumatology SleepMedicine
    ),
    'OutpatientSurgicalSpecialty' => %w(
      CardiacSurgery ColoRectalSurgery ENT GeneralSurgery
      Gynecology Neurosurgery Orthopedics PainManagement
      PlasticSurgery Podiatry ThoracicSurgery Urology
      VascularSurgery
    ),
    'PrimaryCare' => [],
    'Rehabilitation' => [],
    'UrgentCare' => [],
    'WellnessAndPreventativeCare' => []
  }.freeze

  def from_gis_attrs(km, attrs)
    km.each_with_object({}) do |(k, v), h|
      h[k] = if attrs[v].respond_to?(:strip) then attrs[v].strip else attrs[v] end
    end
  end

  def services_from_gis(attrs)
    SERVICE_HIERARCHY.each_with_object([]) do |(k, v), l|
      next unless attrs[k] == 'YES'
      sl2 = []
      v.each do |sk|
        sl2 << sk if attrs[sk] == 'YES'
      end
      l << { 'sl1' => [k], 'sl2' => sl2 }
    end
  end
end
