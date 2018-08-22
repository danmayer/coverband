# frozen_string_literal: true

require 'sinatra/base'

module Coverband
  # TODO can we drop sinatra as a requirement and go to pure rack
  # TODO move to reports and drop need for S3 allow reading from adapters?
  class S3Web < Sinatra::Base
    use Rack::Static,
        root: File.expand_path('public', Gem::Specification.find_by_name('simplecov-html').full_gem_path),
        urls: [/.*\.css/, /.*\.js/, /.*\.gif/, /.*\.png/]

    # todo move to file or template
    get '/' do
      html = "<html>"
      html += "<strong>Notice:</strong> #{Rack::Utils.escape_html(params['notice'])}<br/>" if params['notice']
      html += "<ul>"
      html += "<li><a href='#{base_path}'>Coverband Web Admin Index</a></li>"
      html += "<li><a href='#{base_path}show'>view coverage report</a></li>"
      html += "<li>#{button("#{base_path}collect_coverage",'update coverage data (collect coverage)')}</li>"
      html += "<li>#{button("#{base_path}update_report",'update coverage report (rebuild report)')}</li>"
      html += "<li>#{button("#{base_path}clear",'clear coverage report')}</li>"
      html += "<li>#{button("#{base_path}reload_files",'reload Coverband files')}</li>"
      html += "</ul>"
      html += "<br/>"
      html += "version: #{Coverband::VERSION}<br/>"
      html += "<a href='https://github.com/danmayer/coverband'>Coverband</a>"
      html += "</html>"
      html
    end

    get '/show' do
      html = s3.get_object(bucket: Coverband.configuration.s3_bucket, key: 'coverband/index.html').body.read
      # hack the static HTML assets to account for where this was mounted
      html = html.gsub("src='", "src='#{base_path}")
      html = html.gsub("href='", "href='#{base_path}")
      html = html.gsub("loading.gif", "#{base_path}loading.gif")
      html = html.gsub("/images/", "#{base_path}images/")
      html
    end

    post '/update_report' do
      Coverband::Reporters::SimpleCovReport.report(Coverband.configuration.store, open_report: false)
      notice = "coverband coverage updated"
      redirect "#{base_path}?notice=#{notice}", 301
    end

    post '/collect_coverage' do
      Coverband::Collectors::Base.instance.report_coverage
      notice = "coverband coverage collected"
      redirect "#{base_path}?notice=#{notice}", 301
    end

    post '/clear' do
      Coverband.configuration.store.clear!
      notice = "coverband coverage cleared"
      redirect "#{base_path}?notice=#{notice}", 301
    end

    post '/reload_files' do
      if Coverband.configuration.safe_reload_files
        Coverband.configuration.safe_reload_files.each do |safe_file|
          load safe_file
        end
      end
      # force reload
      Coverband.configure
      notice = "coverband files reloaded"
      redirect "#{base_path}?notice=#{notice}", 301
    end

    private

    def button(url,title)
      button = "<form action='#{url}' method='post'>"
      button += "<button type='submit'>#{title}</button>"
      button += '</form>'
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

    # start the server if ruby file executed directly
    # ruby -I lib -r coverband lib/coverband/s3_web.rb
    # this is really just for testing and development because without configuration
    # Coverband can't do much
    run! if app_file == $0
  end
end
