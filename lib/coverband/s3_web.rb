# frozen_string_literal: true

require 'sinatra/base'

module Coverband
  class S3Web < Sinatra::Base
    set :public_folder, proc(){ File.expand_path('public', Gem::Specification.find_by_name('simplecov-html').full_gem_path) }

    get '/' do
      html = s3.get_object(bucket: Coverband.configuration.s3_bucket, key: 'coverband/index.html').body.read
      # hack the static HTML assets to account for where this was mounted
      html = html.gsub("src='", "src='#{request.path}")
      html = html.gsub("href='", "href='#{request.path}")
      html
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
