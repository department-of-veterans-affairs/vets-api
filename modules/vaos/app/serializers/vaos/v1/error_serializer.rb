# frozen_string_literal: true

module VAOS
  module V1
    class ErrorSerializer
      def initialize(error)
        #{
        #  resourceType: 'OperationOutcome',
        #  issue: serialize_issue(error)
        #}.to_json
        return false
      end

      private

      def serialize_issue(error)

      end
    end
  end
end


#h = {
#  "resourceType"=>"OperationOutcome",
#  "text"=>{
#    "status"=>"generated",
#    "div"=>"<div xmlns=\"http://www.w3.org/1999/xhtml\"><h1>Operation Outcome</h1><table border=\"0\"><tr><td style=\"font-weight: bold;\">error</td><td>[]</td><td><pre>Organization Not Found for identifier: 353000</pre></td>\n\t\t\t\t\t\n\t\t\t\t\n\t\t\t</tr>\n\t\t</table>\n\t</div>"},
#  "issue"=>
#    [
#      {
#        "severity"=>"error",
#        "code"=>"processing",
#        "diagnostics"=>"Organization Not Found for identifier: 353000"
#      }
#    ]
#}
