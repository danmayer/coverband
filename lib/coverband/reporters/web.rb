# frozen_string_literal: true

begin
  require 'rack'
rescue LoadError
  puts 'error loading Coverband web reporter as Rack is not available'
end

module Coverband
  module Reporters
    class Web
      attr_reader :request

      def initialize
        full_path = Gem::Specification.find_by_name('coverband').full_gem_path
        @static = Rack::Static.new(self,
                                   root: File.expand_path('public', full_path),
                                   urls: [/.*\.css/, /.*\.js/, /.*\.gif/, /.*\.png/])
      end

      def check_auth
        return true unless Coverband.configuration.password

        auth_header = request.get_header('HTTP_AUTHORIZATION')
        return unless auth_header

        Coverband.configuration.password == Base64.decode64(auth_header.split[1]).split(':')[1]
      end

      def call(env)
        @request = Rack::Request.new(env)

        return [401, { 'www-authenticate' => 'Basic realm=""' }, ['']] unless check_auth

        if request.post?
          case request.path_info
          when %r{\/clear_file}
            clear_file
          when %r{\/clear}
            clear
          else
            [404, { 'Content-Type' => 'text/html' }, ['404 error!']]
          end
        else
          case request.path_info
          when /.*\.(css|js|gif|png)/
            @static.call(env)
          when %r{\/settings}
            [200, { 'Content-Type' => 'text/html' }, [settings]]
          when %r{\/view_tracker}
            [200, { 'Content-Type' => 'text/html' }, [view_tracker]]
          when %r{\/debug_data}
            [200, { 'Content-Type' => 'text/json' }, [debug_data]]
          when %r{\/load_file_details}
            [200, { 'Content-Type' => 'text/json' }, [load_file_details]]
          when %r{\/$}
            [200, { 'Content-Type' => 'text/html' }, [index]]
          else
            [404, { 'Content-Type' => 'text/html' }, ['404 error!']]
          end
        end
      end

      def index
        notice = "<strong>Notice:</strong> #{Rack::Utils.escape_html(request.params['notice'])}<br/>"
        notice = request.params['notice'] ? notice : ''
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
        Coverband::Utils::HTMLFormatter.new(nil, base_path: base_path).format_view_tracker!
      end

      def debug_data
        Coverband.configuration.store.get_coverage_report.to_json
      end

      def load_file_details
        filename = request.params['filename']
        Coverband::Reporters::HTMLReport.new(Coverband.configuration.store,
                                             filename: filename,
                                             base_path: base_path,
                                             open_report: false).file_details
      end

      def clear
        if Coverband.configuration.web_enable_clear
          Coverband.configuration.store.clear!
          notice = 'coverband coverage cleared'
        else
          notice = 'web_enable_clear isnt enabled in your configuration'
        end
        [301, { 'Location' => "#{base_path}?notice=#{notice}" }, []]
      end

      def clear_file
        if Coverband.configuration.web_enable_clear
          filename = request.params['filename']
          Coverband.configuration.store.clear_file!(filename)
          notice = "coverage for file #{filename} cleared"
        else
          notice = 'web_enable_clear isnt enabled in your configuration'
        end
        [301, { 'Location' => "#{base_path}?notice=#{notice}" }, []]
      end

      private

      # This method should get the root mounted endpoint
      # for example if the app is mounted like so:
      # mount Coverband::Web, at: '/coverage'
      # "/coverage/collect_coverage?" become:
      # /coverage/
      def base_path
        request.path =~ %r{\/.*\/} ? request.path.match("\/.*\/")[0] : '/'
      end
    end
  end
end
