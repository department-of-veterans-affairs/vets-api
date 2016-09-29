# frozen_string_literal: true
require_dependency 'facilities/client'

class VAHealthFacility < ActiveModelSerializers::Model
  attr_accessor :station_id, :station_number, :visn_id, :name, :classification, :lat, :long,
                :address, :phone, :hours, :services

  def self.query(bbox:, services:)
    results = client.query(bbox: bbox.join(','),
                           where: VAHealthFacility.where_clause(services))
    results.each_with_object([]) do |record, facs|
      facs << VAHealthFacility.from_gis(record)
    end
  end

  def self.find_by_id(id:)
    results = client.get(identifier: id)
    VAHealthFacility.from_gis(results.first) unless results.blank?
  end

  def self.service_whitelist
    SERVICE_HIERARCHY.flatten(2)
  end

  def self.where_clause(services)
    services.map { |s| "#{s}='YES'" }.join(' AND ') unless services.nil?
  end

  def self.from_gis(record)
    attrs = record['attributes']
    m = VAHealthFacility.from_gis_attrs(TOP_KEYMAP, attrs)
    m[:address] = VAHealthFacility.from_gis_attrs(ADDR_KEYMAP, attrs)
    m[:phone] = VAHealthFacility.from_gis_attrs(PHONE_KEYMAP, attrs)
    m[:hours] = VAHealthFacility.from_gis_attrs(HOURS_KEYMAP, attrs)
    m[:services] = VAHealthFacility.services_from_gis(attrs)
    VAHealthFacility.new(m)
  end

  TOP_KEYMAP = {
    station_id: 'StationID', station_number: 'StationNumber', visn_id: 'VisnID',
    name: 'StationName', classification: 'CocClassification',
    lat: 'Latitude', long: 'Longitude'
  }.freeze

  ADDR_KEYMAP = {
    'building' => 'Building', 'street' => 'Street', 'suite' => 'Suite',
    'city' => 'City', 'state' => 'State', 'zip' => 'Zip', 'zip4' => 'Zip4'
  }.freeze

  PHONE_KEYMAP = {
    'main' => 'MainPhone', 'fax' => 'MainFax', 'after_hours' => 'AfterHoursPhone',
    'patient_advocate' => 'PatientAdvocatePhone',
    'enrollment_coordinator' => 'EnrollmentCoordinatorPhone',
    'pharmacy' => 'PharmacyPhone'
  }.freeze

  HOURS_KEYMAP = %w(
    Monday Tuesday Wednesday Thursday Friday Saturday Sunday
  ).each_with_object({}) { |d, h| h[d] = d }

  def self.from_gis_attrs(km, attrs)
    km.each_with_object({}) do |(k, v), h|
      h[k] = attrs[v]
    end
  end

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

  def self.services_from_gis(attrs)
    SERVICE_HIERARCHY.each_with_object([]) do |(k, v), l|
      next unless attrs[k] == 'YES'
      sl2 = []
      v.each do |sk|
        sl2 << sk if attrs[sk] == 'YES'
      end
      l << { 'sl1' => [k], 'sl2' => sl2 }
    end
  end

  URL = +ENV['VHA_MAPSERVER_URL']
  LAYER = ENV['VHA_MAPSERVER_LAYER']
  ID_FIELD = 'StationNumber'

  def self.client
    @client ||= Facilities::Client.new(url: URL, layer: LAYER, id_field: ID_FIELD)
  end
end
