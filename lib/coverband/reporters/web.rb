# frozen_string_literal: true

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

      def call(env)
        @request = Rack::Request.new(env)

        return [401, {"www-authenticate" => 'Basic realm=""'}, [""]] unless check_auth

        request_path_info = request.path_info == "" ? "/" : request.path_info
        content_security_policy_header = { "Content-Security-Policy-Report-Only" => CSP_HEADER }
        if request.post?
          case request_path_info
          when %r{\/clear_view_tracking_file}
            clear_view_tracking_file
          when %r{\/clear_view_tracking}
            clear_view_tracking
          when %r{\/clear_file}
            clear_file
          when %r{\/clear}
            clear
          else
            [404, {"Content-Type" => "text/html"}, ["404 error!"]]
          end
        else
          case request_path_info
          when /.*\.(css|js|gif|png)/
            @static.call(env)
          when %r{\/settings}
            [200, {"Content-Type" => "text/html"}.merge(content_security_policy_header), [settings]]
          when %r{\/view_tracker_data}
            [200, {"Content-Type" => "text/json"}.merge(content_security_policy_header), [view_tracker_data]]
          when %r{\/view_tracker}
            [200, {"Content-Type" => "text/html"}.merge(content_security_policy_header), [view_tracker]]
          when %r{\/enriched_debug_data}
            [200, {"Content-Type" => "text/json"}.merge(content_security_policy_header), [enriched_debug_data]]
          when %r{\/debug_data}
            [200, {"Content-Type" => "text/json"}.merge(content_security_policy_header), [debug_data]]
          when %r{\/load_file_details}
            [200, {"Content-Type" => "text/json"}.merge(content_security_policy_header), [load_file_details]]
          when %r{\/$}
            [200, {"Content-Type" => "text/html"}.merge(content_security_policy_header), [index]]
          else
            [404, {"Content-Type" => "text/html"}.merge(content_security_policy_header), ["404 error!"]]
          end
        end
      end

      def index
        notice = "<strong>Notice:</strong> #{Rack::Utils.escape_html(request.params["notice"])}<br/>"
        notice = request.params["notice"] ? notice : ""
        Coverband::Reporters::HTMLReport.new(Coverband.configuration.store,
                                             static: false,
                                             base_path: base_path,
                                             notice: notice,
                                             open_report: false).report
      end

      def settings
        Coverband::Utils::HTMLFormatter.new(nil, base_path: base_path).format_settings!
      end

      def view_tracker
        notice = "<strong>Notice:</strong> #{Rack::Utils.escape_html(request.params["notice"])}<br/>"
        notice = request.params["notice"] ? notice : ""
        Coverband::Utils::HTMLFormatter.new(nil,
                                            notice: notice,
                                            base_path: base_path).format_view_tracker!
      end

      def view_tracker_data
        Coverband::Collectors::ViewTracker.new(store: Coverband.configuration.store).as_json
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
        [301, {"Location" => "#{base_path}?notice=#{notice}"}, []]
      end

      def clear_file
        if Coverband.configuration.web_enable_clear
          filename = request.params["filename"]
          Coverband.configuration.store.clear_file!(filename)
          notice = "coverage for file #{filename} cleared"
        else
          notice = "web_enable_clear isn't enabled in your configuration"
        end
        [301, {"Location" => "#{base_path}?notice=#{notice}"}, []]
      end

      def clear_view_tracking
        if Coverband.configuration.web_enable_clear
          tracker = Coverband::Collectors::ViewTracker.new(store: Coverband.configuration.store)
          tracker.reset_recordings
          notice = "view tracking reset"
        else
          notice = "web_enable_clear isn't enabled in your configuration"
        end
        [301, {"Location" => "#{base_path}/view_tracker?notice=#{notice}"}, []]
      end

      def clear_view_tracking_file
        if Coverband.configuration.web_enable_clear
          tracker = Coverband::Collectors::ViewTracker.new(store: Coverband.configuration.store)
          filename = request.params["filename"]
          tracker.clear_file!(filename)
          notice = "coverage for file #{filename} cleared"
        else
          notice = "web_enable_clear isn't enabled in your configuration"
        end
        [301, {"Location" => "#{base_path}/view_tracker?notice=#{notice}"}, []]
      end

      private

      # This method should get the root mounted endpoint
      # for example if the app is mounted like so:
      # mount Coverband::Web, at: '/coverage'
      # "/coverage/collect_coverage?" become:
      # /coverage/
      # NOTE: DO NOT let standardrb `autofix` this to regex match
      # %r{\/.*\/}.match?(request.path) ? request.path.match("\/.*\/")[0] : "/"
      # ^^ the above is NOT valid Ruby 2.3/2.4 even though rubocop / standard think it is
      def base_path
        request.path =~ %r{\/.*\/} ? request.path.match("\/.*\/")[0] : "/"
      end
    end
  end
end
