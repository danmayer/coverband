# frozen_string_literal: true

require "base64"
require "coverband"

begin
  require "rack"
rescue LoadError
  puts "error loading Coverband web reporter as Rack is not available"
end

module Coverband
  module Reporters
    class WebPager < Web
      def index
        notice = "<strong>Notice:</strong> #{Rack::Utils.escape_html(request.params["notice"])}<br/>"
        notice = request.params["notice"] ? notice : ""
        # TODO: remove the call to the store render empty table
        Coverband::Reporters::HTMLReport.new(Coverband.configuration.store,
          page: (request.params["page"] || 1).to_i,
          static: false,
          base_path: base_path,
          notice: notice,
          open_report: false).report
      end
    end
  end
end
