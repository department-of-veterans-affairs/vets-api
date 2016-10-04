# frozen_string_literal: true
def mvi_savon_valid_response
  instance_double(
    'Savon::Response',
    body: Oj.load(File.read('spec/support/mvi/savon_response_body.json')),
    xml: File.read('spec/support/mvi/find_candidate_response.xml')
  )
end

def mvi_savon_invalid_response
  xml = File.read('spec/support/mvi/find_candidate_invalid_response.xml')
  bad_response('AR', xml)
end

def mvi_savon_failure_response
  xml = File.read('spec/support/mvi/find_candidate_failure_response.xml')
  bad_response('AE', xml)
end

def bad_response(code, xml)
  instance_double(
    'Savon::Response',
    body: {
      prpa_in201306_uv02: {
        acknowledgement: { type_code: { :@code => code } }
      }
    },
    xml: xml
  )
end
