# frozen_string_literal: true

require 'rack'

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

      def call(env)
        @request = Rack::Request.new(env)

        if request.post?
          case request.path_info
          when %r{\/clear}
            clear
          when %r{\/collect_coverage}
            collect_coverage
          when %r{\/reload_files}
            reload_files
          else
            [404, { 'Content-Type' => 'text/html' }, ['404 error!']]
          end
        else
          case request.path_info
          when /.*\.(css|js|gif|png)/
            @static.call(env)
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
        Coverband::Reporters::HTMLReport.report(Coverband.configuration.store,
                                                html: true,
                                                base_path: base_path,
                                                notice: notice,
                                                open_report: false)
      end

      def collect_coverage
        Coverband::Collectors::Coverage.instance.report_coverage(true)
        notice = 'coverband coverage collected'
        [301, { 'Location' => "#{base_path}?notice=#{notice}" }, []]
      end

      def clear
        Coverband.configuration.store.clear!
        notice = 'coverband coverage cleared'
        [301, { 'Location' => "#{base_path}?notice=#{notice}" }, []]
      end

      def reload_files
        Coverband.configuration&.safe_reload_files&.each do |safe_file|
          load safe_file
        end
        # force reload
        Coverband.configure
        notice = 'coverband files reloaded'
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
