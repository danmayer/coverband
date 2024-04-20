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
    class Web
      attr_reader :request

      CSP_HEADER = [
        "default-src 'self' https: http:",
        "child-src 'self'",
        "connect-src 'self' https: http: wss: ws:",
        "font-src 'self' https: http:",
        "frame-src 'self'",
        "img-src 'self' https: http: data:",
        "manifest-src 'self'",
        "media-src 'self'",
        "object-src 'none'",
        "script-src 'self' https: http: 'unsafe-inline'",
        "style-src 'self' https: http: 'unsafe-inline'",
        "worker-src 'self'",
        "base-uri 'self'"
      ].join("; ").freeze

      def init_web
        full_path = Gem::Specification.find_by_name("coverband").full_gem_path
        @static = Rack::Static.new(self,
          root: File.expand_path("public", full_path),
          urls: [/.*\.css/, /.*\.js/, /.*\.gif/, /.*\.png/])
      end

      def check_auth
        return true unless Coverband.configuration.password

        # support rack 1.6.x and rack 2.0 (get_header)
        auth_header = request.respond_to?(:get_header) ? request.get_header("HTTP_AUTHORIZATION") : request.env["HTTP_AUTHORIZATION"]
        return unless auth_header

        Coverband.configuration.password == Base64.decode64(auth_header.split[1]).split(":")[1]
      end

      def self.call(env)
        @app ||= new
        @app.call(env)
      end

      def call(env)
        @request = Rack::Request.new(env)

        return [401, {"www-authenticate" => 'Basic realm=""'}, [""]] unless check_auth

        request_path_info = (request.path_info == "") ? "/" : request.path_info
        tracker_route = false
        Coverband.configuration.trackers.each do |tracker|
          if request_path_info.match(tracker.class::REPORT_ROUTE)
            tracker_route = true
            if request_path_info =~ %r{\/clear_.*_key}
              return clear_abstract_tracking_key(tracker)
            elsif request_path_info =~ %r{\/clear_.*}
              return clear_abstract_tracking(tracker)
            else
              return [200, {"content-type" => "text/html"}, [display_abstract_tracker(tracker)]]
            end
          end
        end

        unless tracker_route
          if request.post?
            case request_path_info
            when %r{\/clear_file}
              clear_file
            when %r{\/clear}
              clear
            else
              [404, coverband_headers, ["404 error!"]]
            end
          else
            case request_path_info
            when /.*\.(css|js|gif|png)/
              @static.call(env)
            when %r{\/settings}
              [200, coverband_headers, [settings]]
            when %r{\/view_tracker_data}
              [200, coverband_headers(content_type: "text/json"), [view_tracker_data]]
            when %r{\/enriched_debug_data}
              [200, coverband_headers(content_type: "text/json"), [enriched_debug_data]]
            when %r{\/debug_data}
              [200, coverband_headers(content_type: "text/json"), [debug_data]]
            when %r{\/load_file_details}
              [200, coverband_headers(content_type: "text/json"), [load_file_details]]
            when %r{\/json}
              [200, coverband_headers(content_type: "text/json"), [json]]
            when %r{\/report_json}
              [200, coverband_headers(content_type: "text/json"), [report_json]]
            when %r{\/$}
              [200, coverband_headers, [index]]
            else
              [404, coverband_headers, ["404 error!"]]
            end
          end
        end
      end

      def index
        notice = "<strong>Notice:</strong> #{Rack::Utils.escape_html(request.params["notice"])}<br/>"
        notice = request.params["notice"] ? notice : ""
        page = (request.params["page"] || 1).to_i
        options = {
          static: false,
          base_path: base_path,
          notice: notice,
          open_report: false
        }
        options[:page] = page if Coverband.configuration.paged_reporting
        Coverband::Reporters::HTMLReport.new(Coverband.configuration.store,
          options).report
      end

      def json
        Coverband::Reporters::JSONReport.new(Coverband.configuration.store).report
      end

      def report_json
        report_options = {
          as_report: true,
          base_path: base_path
        }
        report_options[:page] = (request.params["page"] || 1).to_i if request.params["page"]
        Coverband::Reporters::JSONReport.new(
          Coverband.configuration.store,
          report_options
        ).report
      end

      def settings
        return "" if Coverband.configuration.hide_settings
        Coverband::Utils::HTMLFormatter.new(nil, base_path: base_path).format_settings!
      end

      def display_abstract_tracker(tracker)
        notice = "<strong>Notice:</strong> #{Rack::Utils.escape_html(request.params["notice"])}<br/>"
        notice = request.params["notice"] ? notice : ""
        options = {
          tracker: tracker,
          notice: notice,
          base_path: base_path
        }
        Coverband::Utils::HTMLFormatter.new(nil, options).format_abstract_tracker!
      end

      def view_tracker_data
        Coverband::Collectors::ViewTracker.new.as_json
      end

      def debug_data
        Coverband.configuration.store.get_coverage_report.to_json
      end

      def enriched_debug_data
        Coverband::Reporters::HTMLReport.new(Coverband.configuration.store,
          static: false,
          base_path: base_path,
          notice: "",
          open_report: false).report_data
      end

      def load_file_details
        filename = request.params["filename"]
        Coverband::Reporters::HTMLReport.new(Coverband.configuration.store,
          filename: filename,
          base_path: base_path,
          open_report: false).file_details
      end

      def clear
        if Coverband.configuration.web_enable_clear
          Coverband.configuration.store.clear!
          notice = "coverband coverage cleared"
        else
          notice = "web_enable_clear isn't enabled in your configuration"
        end
        [302, {"Location" => "#{base_path}?notice=#{notice}"}, []]
      end

      def clear_file
        if Coverband.configuration.web_enable_clear
          filename = request.params["filename"]
          Coverband.configuration.store.clear_file!(filename)
          notice = "coverage for file #{filename} cleared"
        else
          notice = "web_enable_clear isn't enabled in your configuration"
        end
        [302, {"Location" => "#{base_path}?notice=#{notice}"}, []]
      end

      def clear_abstract_tracking(tracker)
        if Coverband.configuration.web_enable_clear
          tracker.reset_recordings
          notice = "#{tracker.title} tracking reset"
        else
          notice = "web_enable_clear isn't enabled in your configuration"
        end
        [302, {"Location" => "#{base_path}/#{tracker.route}?notice=#{notice}"}, []]
      end

      def clear_abstract_tracking_key(tracker)
        if Coverband.configuration.web_enable_clear
          key = request.params["key"]
          tracker.clear_key!(key)
          notice = "coverage for #{tracker.title} #{key} cleared"
        else
          notice = "web_enable_clear isn't enabled in your configuration"
        end
        [302, {"Location" => "#{base_path}/#{tracker.route}?notice=#{notice}"}, []]
      end

      private

      def coverband_headers(content_type: "text/html")
        web_headers = {
          "content-type" => content_type
        }
        web_headers["content-security-policy-report-only"] = CSP_HEADER if Coverband.configuration.csp_policy
        web_headers
      end

      # This method should get the root mounted endpoint
      # for example if the app is mounted like so:
      # mount Coverband::Web, at: '/coverage'
      # "/coverage/collect_coverage?" become:
      # /coverage/
      # NOTE: DO NOT let standardrb `autofix` this to regex match
      # %r{\/.*\/}.match?(request.path) ? request.path.match("\/.*\/")[0] : "/"
      # ^^ the above is NOT valid Ruby 2.3/2.4 even though rubocop / standard think it is
      def base_path
        (request.path =~ %r{\/.*\/}) ? request.path.match("/.*/")[0] : "/"
      end
    end
  end
end
