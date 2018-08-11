# frozen_string_literal: true

require 'sinatra/base'

module Coverband
  class S3Web < Sinatra::Base
    set :public_folder, proc(){ File.expand_path('public', Gem::Specification.find_by_name('simplecov-html').full_gem_path) }

    get '/actions' do
      base_path = request.path.gsub('/actions','')
      html = "<html>"
      html += "<ul>"
      html += "<li><a href='#{base_path}'>view coverage report</a></li>"
      html += "<li><a href='#{base_path}/update_report'>update coverage report</a></li>"
      html += "<li><a href='#{base_path}/clear'>clear coverage report</a></li>"
      html += "<li><a href='#{base_path}/reload_files'>reload Coverband files</a></li>"
      html += "</ul>"
      html += "</html>"
      html
    end

    get '/' do
      html = s3.get_object(bucket: Coverband.configuration.s3_bucket, key: 'coverband/index.html').body.read
      # hack the static HTML assets to account for where this was mounted
      html = html.gsub("src='", "src='#{request.path}")
      html = html.gsub("href='", "href='#{request.path}")
      html = html.gsub("loading.gif", "#{request.path}loading.gif")
      html = html.gsub("/images/", "#{request.path}/images/")
      html
    end

    post '/update_report' do
      Coverband::Reporters::SimpleCovReport.report(Coverband.configuration.store, open_report: false)
      notice = "coverband coverage updated"
      redirect "/?notice=#{notice}", 301
    end

    post '/clear' do
      Coverband.configuration.store.clear!
      notice = "coverband coverage cleared"
      redirect "/?notice=#{notice}", 301
    end

    post '/reload_files' do
      if Coverband.configuration.safe_reload_files
        Coverband.configuration.safe_reload_files.each do |safe_file|
          load safe_file
        end
      end
      Coverband.configure
      notice = "coverband files reloaded"
      redirect "/?notice=#{notice}", 301
    end

    private

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
