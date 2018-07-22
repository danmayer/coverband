# frozen_string_literal: true

require 'sinatra/base'

module Coverband
  class S3Web < Sinatra::Base
    set :public_folder, proc(){ File.expand_path('public', Gem::Specification.find_by_name('simplecov-html').full_gem_path) }

    get '/' do
      s3.get_object(bucket: Coverband.configuration.s3_bucket, key: 'coverband/index.html').body.read
    end

    private

    def s3
      begin
        require 'aws-sdk'
      rescue StandardError
        Coverband.configuration.logger.error "coverband requires 'aws-sdk' in order use S3ReportWriter."
        return
      end
      @s3 ||= Aws::S3::Client.new
    end
  end
end
