# frozen_string_literal: true

require 'rack'

module Coverband
  module Reporters
    # TODO: move to reports and drop need for S3 allow reading from adapters?
    class Web
      attr_reader :request

      def initialize
        full_path = Gem::Specification.find_by_name('simplecov-html').full_gem_path
        @static = Rack::Static.new(self,
                                   root: File.expand_path('public', full_path),
                                   urls: [/.*\.css/, /.*\.js/, /.*\.gif/, /.*\.png/])
      end

      def call(env)
        @request = Rack::Request.new(env)

        if request.post?
          case request.path_info
          when %r{\/collect_update_and_view}
            collect_update_and_view
          when %r{\/clear}
            clear
          when %r{\/update_report}
            update_report
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
          when %r{\/show}
            [200, { 'Content-Type' => 'text/html' }, [show]]
          when %r{\/}
            [200, { 'Content-Type' => 'text/html' }, [index]]
          else
            [404, { 'Content-Type' => 'text/html' }, ['404 error!']]
          end
        end
      end

      # TODO: move to file or template
      def index
        notice = "<strong>Notice:</strong> #{Rack::Utils.escape_html(request.params['notice'])}<br/>"
        notice = request.params['notice'] ? notice : ''
        %(
<html>
  #{notice}
  <ul>
    <li><a href='#{base_path}'>Coverband Web Admin Index</a></li>
    <li>#{button("#{base_path}collect_update_and_view", 'collect data, update report, & view')}</li>
    <li><a href='#{base_path}show'>view coverage report</a></li>
    <li>#{button("#{base_path}collect_coverage", 'update coverage data (collect coverage)')}</li>
    <li>#{button("#{base_path}update_report", 'update coverage report (rebuild report)')}</li>
    <li>#{button("#{base_path}clear", 'clear coverage report')}</li>
    <li>#{button("#{base_path}reload_files", 'reload Coverband files')}</li>
  </ul>
  <br/>
  version: #{Coverband::VERSION}<br/>
  <a href='https://github.com/danmayer/coverband'>Coverband</a>
</html>
)
      end

      def show
        html = s3.get_object(bucket: Coverband.configuration.s3_bucket, key: 'coverband/index.html').body.read
        # HACK: the static HTML assets to link to the path where this was mounted
        html = html.gsub("src='", "src='#{base_path}")
        html = html.gsub("href='", "href='#{base_path}")
        html = html.gsub('loading.gif', "#{base_path}loading.gif")
        html = html.gsub('/images/', "#{base_path}images/")
        html
      end

      def collect_update_and_view
        collect_coverage
        update_report
        [301, { 'Location' => "#{base_path}show" }, []]
      end

      def update_report
        Coverband::Reporters::SimpleCovReport.report(Coverband.configuration.store, open_report: false)
        notice = 'coverband coverage updated'
        [301, { 'Location' => "#{base_path}?notice=#{notice}" }, []]
      end

      def collect_coverage
        Coverband::Collectors::Coverage.instance.report_coverage
        notice = 'coverband coverage collected'
        [301, { 'Location' => "#{base_path}?notice=#{notice}" }, []]
      end

      def clear
        Coverband.configuration.store.clear!
        notice = 'coverband coverage cleared'
        [301, { 'Location' => "#{base_path}?notice=#{notice}" }, []]
      end

      def reload_files
        if Coverband.configuration.safe_reload_files
          Coverband.configuration.safe_reload_files.each do |safe_file|
            load safe_file
          end
        end
        # force reload
        Coverband.configure
        notice = 'coverband files reloaded'
        [301, { 'Location' => "#{base_path}?notice=#{notice}" }, []]
      end

      private

      def button(url, title)
        button = "<form action='#{url}' method='post'>"
        button += "<button type='submit'>#{title}</button>"
        button + '</form>'
      end

      # This method should get the root mounted endpoint
      # for example if the app is mounted like so:
      # mount Coverband::S3Web, at: '/coverage'
      # "/coverage/collect_coverage?" become:
      # /coverage/
      def base_path
        request.path.match("\/.*\/") ? request.path.match("\/.*\/")[0] : '/'
      end

      def s3
        begin
          require 'aws-sdk'
        rescue StandardError
          Coverband.configuration.logger.error "coverband requires 'aws-sdk' in order use S3ReportWriter."
          return
        end
        @s3 ||= begin
          client_options = {
            region: Coverband.configuration.s3_region,
            access_key_id: Coverband.configuration.s3_access_key_id,
            secret_access_key: Coverband.configuration.s3_secret_access_key
          }
          client_options = {} if client_options.values.any?(&:nil?)
          Aws::S3::Client.new(client_options)
        end
      end
    end
  end
end
