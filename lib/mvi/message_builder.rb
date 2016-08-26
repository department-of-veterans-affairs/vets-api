require 'ox'

module MVI
  class MessageBuilder
    attr_reader :message

    SITE_KEY = 'ABC123'.freeze
    ROOT_ID = '2.16.840.1.113883.4.349'.freeze
    INTERACTION_ID = '^PN^200VETS^USDVA'.freeze
    EXTENSIONS = {
      add_person: 'PRPA_IN201301UV02',
      find_candidate: 'PRPA_IN201305UV02',
      update_person: 'PRPA_IN201302UV02'
    }.freeze

    def initialize
      @message = Ox::Document.new(:version => '1.0')
    end

    def build_find_candidate(vcid, first, last, dob, ssn)
      self.header(vcid, EXTENSIONS[:find_candidate])
      Ox.dump(@message)
    end

    # Generates a header like:
    #
    # <id root="2.16.840.1.113883.3.933" extension="MCID‐12345" />
    # <creationTime value="20070810140900" />
    # <interactionId root="2.16.840.1.113883.1.6" extension="PRPA_IN201309UV02" />
    # <processingCode code="T" />
    # <processingModeCode code="T" />
    # <acceptAckCode code="AL" />
    # <receiver typeCode="RCV">
    #   <device classCode="DEV" determinerCode="INSTANCE"> <id root="2.16.840.1.113883.4.349" />
    #   </device>
    # </receiver>
    # <sender typeCode="SND">
    #   <device classCode="DEV" determinerCode="INSTANCE">
    #   <id root="2.16.840.1.113883.3.933" extension="SITEKEY_OBTAINED_FROM_MVI"/> </device>
    # </sender>

    def header(vcid, extension)
      @message << element('id', root: ROOT_ID, extension: "#{vcid}#{INTERACTION_ID}")
      @message << element('creationTime', value: Time.now.strftime.utc('%Y%m%d%M%H%M%S'))
      @message << element('interactionId', root: ROOT_ID, extension: extension)
      @message << element('processingCode', code: Rails.env.production? ? 'P' : 'D')
      @message << element('processingModeCode', code: 'T')
      @message << element('acceptAckCode', code: 'AL')
      receiver = element('receiver', typeCode: 'RCV')
      device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
      id = element('id', root: ROOT_ID)
      device << id
      receiver << device
      @message << receiver
      sender = element('sender', typeCode: 'SND')
      device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
      sender << device
      id = element('id', root: ROOT_ID, extension: SITE_KEY)
      sender << id
      @message << sender
    end

    def element(name, attrs = nil)
      el = Ox::Element.new(name)
      return el unless attrs
      attrs.each { |k, v| el[k] = v }
      el
    end
  end
end
